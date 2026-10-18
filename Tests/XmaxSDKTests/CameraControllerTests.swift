//
//  CameraControllerTests.swift
//  XmaxSDK
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit
import XCTest
@testable import XmaxSDK

final class CameraControllerTests: XCTestCase, @unchecked Sendable {

    private let builtIn = CameraDevice(id: "builtin", name: "Built-in", isDefault: true, position: .unspecified)
    private let external = CameraDevice(id: "usb", name: "USB", isDefault: false, position: .unspecified)
    private let format = RealtimeVideoFormat(width: 1920, height: 1024, fps: 30)

    func testDefaultCameraUsesSystemDefaultInsteadOfFirstDevice() async throws {
        let capture = CameraCaptureManagingStub(devices: [external, builtIn])
        let controller = makeController(capture)
        let stream = try await controller.createLocalCameraStream(videoFormat: format, deviceID: nil)
        XCTAssertEqual(stream.videoTrack?.device, builtIn)
        XCTAssertEqual(capture.calls, [.start("builtin")])
        await controller.stopLocalCameraStream()
    }

    func testExplicitUnavailableDeviceDoesNotFallBackToDefault() async {
        let capture = CameraCaptureManagingStub(devices: [builtIn])
        let controller = makeController(capture)
        do {
            _ = try await controller.createLocalCameraStream(videoFormat: format, deviceID: "removed")
            XCTFail("Expected unavailable device to fail")
        } catch {
            XCTAssertEqual((error as? XmaxError)?.code, .mediaError)
        }
        XCTAssertTrue(capture.calls.isEmpty)
        XCTAssertNil(controller.currentTrack)
    }

    func testCameraSwitchKeepsTrackIdentityAndUpdatesDevice() async throws {
        let capture = CameraCaptureManagingStub(devices: [builtIn, external])
        let controller = makeController(capture)
        let local = try await controller.createLocalCameraStream(videoFormat: format, deviceID: "builtin")
        let switched = try await controller.switchCamera(to: "usb")
        XCTAssertTrue(local.videoTrack === switched.videoTrack)
        XCTAssertEqual(switched.videoTrack?.device, external)
        XCTAssertEqual(capture.calls, [.start("builtin"), .switchCamera("usb")])
        await controller.stopLocalCameraStream()
    }

    func testFailedSwitchPreservesCurrentDevice() async throws {
        let capture = CameraCaptureManagingStub(
            devices: [builtIn, external], startError: nil,
            switchError: XmaxError(code: .mediaError, message: "Device unavailable")
        )
        let controller = makeController(capture)
        _ = try await controller.createLocalCameraStream(videoFormat: format, deviceID: nil)
        do {
            _ = try await controller.switchCamera(to: "usb")
            XCTFail("Expected device switch failure")
        } catch {
            XCTAssertEqual(controller.currentTrack?.device, builtIn)
        }
        await controller.stopLocalCameraStream()
    }

    func testCaptureFailureReleasesTrackAndRenderBinding() async {
        let capture = CameraCaptureManagingStub(
            devices: [builtIn], startError: XmaxError(code: .mediaError, message: "Capture failed")
        )
        let controller = makeController(capture)
        do {
            _ = try await controller.createLocalCameraStream(videoFormat: format, deviceID: nil)
            XCTFail("Expected capture failure")
        } catch {
            XCTAssertNil(controller.currentTrack)
            XCTAssertEqual(capture.calls, [.start("builtin"), .stop])
        }
    }

    @MainActor
    func testReadyRequiresCapturedFrameAndPreviewBindingAndBecomesInvalidAfterStop() async throws {
        let capture = CameraCaptureManagingStub(devices: [builtIn])
        let controller = makeController(capture)
        let stream = try await controller.createLocalCameraStream(videoFormat: format, deviceID: nil)
        let track = try XCTUnwrap(stream.videoTrack)
        let ready = expectation(description: "Preview ready")
        var receivedReady = false
        var isCurrent: (@Sendable () -> Bool)?
        controller.setPreviewReadyHandler { validity in
            receivedReady = true
            isCurrent = validity
            ready.fulfill()
        }
        let frame = try VideoFrame(
            format: VideoFormat(width: 4, height: 4, pixelFormat: .nv12), timestampUs: 1,
            planes: [
                VideoFramePlane(data: Data(repeating: 16, count: 16), stride: 4),
                VideoFramePlane(data: Data(repeating: 128, count: 8), stride: 4)
            ]
        )
        let oldFrameListener = capture.currentFrameListener
        try oldFrameListener?(frame)
        await Task.yield()
        XCTAssertFalse(receivedReady)
        let view = XmaxVideoView()
        try VideoRenderRegistry.binding(for: track)?.attach(to: view, contentMode: .fit)
        await fulfillment(of: [ready], timeout: 2)
        XCTAssertEqual(isCurrent?(), true)
        await controller.stopLocalCameraStream()
        XCTAssertEqual(isCurrent?(), false)
        XCTAssertNil(VideoRenderRegistry.binding(for: track))
        try oldFrameListener?(frame)
        XCTAssertNil(controller.currentTrack)
    }

    private func makeController(_ capture: CameraCaptureManagingStub) -> CameraController {
        CameraController(
            rtcManager: RtcManagingStub(), permissionManager: PermissionManagingStub(),
            mediaService: MediaService(), captureManager: capture
        )
    }
}
