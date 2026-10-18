//
//  ExternalVideoFrameSink.swift
//  XmaxSDK
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import CoreVideo
import Foundation

/// Serializes external frame submission and invalidates a binding before source cleanup.
final class ExternalVideoFrameSink: RealtimeExternalFrameSink, @unchecked Sendable {

    /// Input configuration
    let videoFormat: RealtimeVideoFormat
    private let requestingFrames: @Sendable () -> Bool
    private let videoFrameListener: MediaVideoFrameListener
    private let errorListener: XmaxErrorListener

    /// Binding state (protected by lock)
    private let lock = NSLock()
    private var active = true
    private var lastTimestampUs: Int64 = -1

    /// Creates the sink for one binding with immutable negotiated input configuration.
    init(
        videoFormat: RealtimeVideoFormat,
        requestingFrames: @escaping @Sendable () -> Bool,
        videoFrameListener: @escaping MediaVideoFrameListener,
        errorListener: @escaping XmaxErrorListener
    ) {
        self.videoFormat = videoFormat
        self.requestingFrames = requestingFrames
        self.videoFrameListener = videoFrameListener
        self.errorListener = errorListener
    }

    var isRequestingFrames: Bool {
        lock.withLock { active && requestingFrames() }
    }

    /// Copies and submits a valid requested frame synchronously under the binding lock.
    func pushVideo(_ pixelBuffer: CVPixelBuffer, timestampUs: Int64) {
        lock.withLock {
            guard active, requestingFrames(), timestampUs >= 0, timestampUs > lastTimestampUs else { return }
            do {
                let frame = try ExternalVideoFrameConverter.convert(
                    pixelBuffer, videoFormat: videoFormat, timestampUs: timestampUs
                )
                lastTimestampUs = timestampUs
                try videoFrameListener(frame)
            } catch {
                reportFailure(error)
            }
        }
    }

    /// Reports errors only while this binding remains active.
    func reportError(_ error: any Error) {
        lock.withLock {
            guard active else { return }
            reportFailure(error)
        }
    }

    /// Waits for in-flight submission and permanently rejects subsequent input.
    func invalidate() {
        lock.withLock { active = false }
    }

    /// Forwards the first binding failure; the SDK lifecycle handler performs cleanup.
    private func reportFailure(_ error: any Error) {
        active = false
        errorListener(XmaxError(code: .mediaError, message: "External video source failed: \(error.localizedDescription)"))
    }
}
