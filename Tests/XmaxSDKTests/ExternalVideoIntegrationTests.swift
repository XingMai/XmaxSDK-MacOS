//
//  ExternalVideoIntegrationTests.swift
//  XmaxSDK
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import CoreMedia
import XCTest
@testable import XmaxSDK

@MainActor
final class ExternalVideoIntegrationTests: XCTestCase {

    func testExternalStopDoesNotAdvanceCameraPreviewReadiness() async throws {
        let rtc = RtcManagingStub()
        let camera = CameraController(
            rtcManager: rtc, permissionManager: PermissionManagingStub(),
            mediaService: MediaServicingStub(resolvedSize: CGSize(width: 4, height: 4)),
            captureManager: CameraCaptureManagingStub(devices: [
                CameraDevice(id: "camera", name: "Camera", isDefault: true, position: .front)
            ])
        )
        let components = makeComponents(rtc: rtc, camera: camera)
        _ = try await components.manager.createLocalCameraStream(
            videoFormat: RealtimeVideoFormat(width: 4, height: 4, fps: 30), deviceID: nil
        )
        try await components.manager.stopExternalVideoStream()
        let state = await components.manager.currentState
        XCTAssertEqual(state.connectionState, .preparing)
        XCTAssertNotNil(camera.currentTrack)
        await components.manager.close()
    }

    func testBindingIsReadyWithoutFramesOrPreviewAndEnforcesSingleMediaOwnership() async throws {
        let components = makeComponents()
        let manager: any XmaxRealtimeManaging = components.manager
        let source = ExternalSourceStub()
        let local = try await manager.createExternalVideoStream(source: source)
        let ready = await manager.currentState
        XCTAssertEqual(ready.connectionState, .ready)
        XCTAssertFalse(source.sink?.isRequestingFrames ?? true)
        let ownsLocal = await components.media.owns(local)
        XCTAssertTrue(ownsLocal)
        do {
            _ = try await manager.createExternalVideoStream(source: ExternalSourceStub())
            XCTFail("Expected single media ownership")
        } catch {
            XCTAssertEqual((error as? XmaxError)?.code, .invalidConfiguration)
        }
        XCTAssertEqual(source.stops, 0)
        try await manager.stopExternalVideoStream()
        try await manager.stopExternalVideoStream()
        let idle = await manager.currentState
        XCTAssertEqual(idle.connectionState, .idle)
        XCTAssertEqual(source.stops, 1)
        XCTAssertEqual(components.rtc.calls.filter { $0 == .destroy }.count, 1)
    }

    func testFramesFlowDuringGenerationStartupAndDisconnectRetainsTheBinding() async throws {
        let components = makeComponents()
        let manager = components.manager
        let source = ExternalSourceStub()
        let local = try await manager.createExternalVideoStream(source: source, videoFormat: nil)
        let sink = try XCTUnwrap(source.sink)
        let generation = Task {
            try await manager.startGeneration(
                localStream: local,
                context: RealtimeContext(prompt: "test"), faceRestoration: false
            )
        }
        try await waitUntil { sink.isRequestingFrames }
        sink.pushVideo(try ExternalVideoControllerTests.makeBuffer(), timestampUs: 1)
        XCTAssertTrue(components.rtc.calls.contains(.pushExternalVideoFrame))
        components.rtc.emitRemoteVideoAvailable(stream: RemoteStream(roomID: "room", userID: "bot"))
        try await waitUntil {
            components.rtc.calls.contains {
                if case .setRemoteVideoFrameListener(_, enabled: true) = $0 { return true }
                return false
            }
        }
        try components.rtc.emitRemoteVideoFrame(width: 4, height: 4, presentationTimeStamp: .zero)
        let remote = try await generation.value
        XCTAssertNotNil(remote.videoTrack)
        let generating = await manager.currentState
        XCTAssertEqual(generating.connectionState, .generating)
        XCTAssertTrue(sink.isRequestingFrames)
        do {
            try await manager.stopExternalVideoStream()
            XCTFail("Expected disconnect requirement")
        } catch {
            XCTAssertEqual((error as? XmaxError)?.code, .invalidConfiguration)
        }
        XCTAssertEqual(source.stops, 0)

        await manager.disconnect()
        XCTAssertFalse(sink.isRequestingFrames)
        XCTAssertNotNil(source.sink)
        XCTAssertEqual(source.stops, 0)
        XCTAssertFalse(components.rtc.calls.contains(.destroy))
        let ownedAfterDisconnect = await components.media.owns(local)
        XCTAssertTrue(ownedAfterDisconnect)
        try await manager.stopExternalVideoStream()
        XCTAssertEqual(source.stops, 1)
        await manager.close()
        XCTAssertEqual(components.rtc.calls.filter { $0 == .destroy }.count, 1)
    }

    func testSourceFailureCleansUpAndOldErrorsCannotAffectTheNextBinding() async throws {
        let components = makeComponents()
        let source = ExternalSourceStub()
        _ = try await components.manager.createExternalVideoStream(source: source, videoFormat: nil)
        let oldSink = try XCTUnwrap(source.sink)
        oldSink.reportError(XmaxError(code: .mediaError, message: "Camera disconnected"))
        try await waitUntil { source.stops == 1 }
        let failed = await components.manager.currentState
        XCTAssertEqual(failed.connectionState, .idle)
        guard case let .failure(error) = failed.reason else {
            return XCTFail("Expected external media failure")
        }
        XCTAssertEqual(error.code, .mediaError)
        let next = ExternalSourceStub()
        _ = try await components.manager.createExternalVideoStream(source: next, videoFormat: nil)
        oldSink.reportError(XmaxError(code: .mediaError, message: "Late error"))
        await Task.yield()
        let ready = await components.manager.currentState
        XCTAssertEqual(ready.connectionState, .ready)
        XCTAssertEqual(next.stops, 0)
        await components.manager.close()
    }

    func testCloseCancelsSuspendedSourceBindingAndAllowsReuse() async throws {
        let components = makeComponents()
        let source = ExternalSourceStub()
        source.startHandler = { try await Task.sleep(for: .seconds(30)) }
        let creation = Task {
            try await components.manager.createExternalVideoStream(source: source, videoFormat: nil)
        }
        try await waitUntil { source.sink != nil }
        await components.manager.close()
        do {
            _ = try await creation.value
            XCTFail("Expected cancelled creation")
        } catch {
            XCTAssertEqual((error as? XmaxError)?.code, .cancelled)
        }
        XCTAssertEqual(source.stops, 1)
        XCTAssertFalse(source.lastSink?.isRequestingFrames ?? true)
        let state = await components.manager.currentState
        XCTAssertEqual(state.connectionState, .idle)
        _ = try await components.manager.createExternalVideoStream(source: ExternalSourceStub(), videoFormat: nil)
        await components.manager.close()
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while !predicate() {
            guard ContinuousClock.now < deadline else {
                throw XmaxError(code: .timeout, message: "External input test condition timed out")
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func makeComponents(
        rtc: RtcManagingStub = RtcManagingStub(),
        camera: (any CameraControlling)? = nil
    ) -> (manager: XmaxRealtimeManager, media: MediaController, rtc: RtcManagingStub) {
        let errors = RealtimeErrorHandler()
        let timing = RealtimeTiming()
        let service = MediaServicingStub(resolvedSize: CGSize(width: 4, height: 4))
        let render = RenderController(rtcManager: rtc, errorListener: { errors.forward($0, target: .connection) })
        let stream = StreamController(
            rtcManager: rtc,
            errorListener: { errors.forward($0, target: .connection) },
            remoteStreamListener: { try render.setRemoteStream($0) }, timing: timing
        )
        let media: MediaController
        if let camera {
            media = MediaController(rtcManager: rtc, cameraController: camera)
        } else {
            media = MediaController(
                rtcManager: rtc, mediaService: service,
                videoFrameListener: { try stream.pushLocalVideoFrame($0) },
                requestingFrames: { stream.hasGenerationTask },
                errorListener: { errors.forward($0, target: .all) },
                interactionListener: { try await stream.sendTracks(taskID: $0, points: $1) }
            )
        }
        let session = RealtimeSession(
            id: "session", userID: "user", status: "ACTIVE",
            connection: RealtimeSessionConnection(roomID: "room", userID: "user", token: "token", botName: "bot"),
            closeReason: nil
        )
        let connection = XmaxRealtimeConnectionManager(
            sessionService: RealtimeSessionServicingStub(session: session),
            interactionController: media, renderController: render, streamController: stream, timing: timing
        )
        let generation = XmaxRealtimeGenerationManager(interactionController: media, streamController: stream)
        let manager = XmaxRealtimeManager(
            options: RealtimeConfiguration(model: .x2_1_1_preview_cn),
            streamController: stream, mediaController: media, renderController: render,
            mediaService: service, connectionManager: connection, errorHandler: errors,
            generationManager: generation, timing: timing
        )
        return (manager, media, rtc)
    }
}
