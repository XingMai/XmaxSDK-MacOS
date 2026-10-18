//
//  RealtimeVideoTrack.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// A realtime video track and its dynamic metadata.
public final class RealtimeVideoTrack: @unchecked Sendable {

    /// The video track identifier.
    public let id: String

    /// Dynamic metadata
    private let metadataLock = NSLock()
    private var metadata: Metadata

    /// Creates a video track with the specified identity and initial metadata.
    ///
    /// - Parameters:
    ///   - id: The unique track identifier.
    ///   - videoFormat: The initial video format; `nil` if not yet known.
    ///   - position: The local camera position; `nil` for non-camera tracks.
    init(
        id: String,
        videoFormat: RealtimeVideoFormat? = nil,
        position: CameraPosition? = nil,
        device: CameraDevice? = nil
    ) {
        self.id = id
        metadata = Metadata(
            videoFormat: videoFormat,
            position: position,
            device: device
        )
    }

    /// The video format currently used by the track.
    public var videoFormat: RealtimeVideoFormat? {
        metadataLock.withLock { metadata.videoFormat }
    }

    /// The camera position currently used by the local camera track.
    public var position: CameraPosition? {
        metadataLock.withLock { metadata.position }
    }

    /// The current camera device; nil for non-camera tracks.
    public var device: CameraDevice? {
        metadataLock.withLock { metadata.device }
    }

    /// Updates device metadata while retaining video track identity.
    ///
    /// - Parameter device: The camera device after switching completes.
    func updateDevice(_ device: CameraDevice) {
        metadataLock.withLock {
            metadata.device = device
            metadata.position = device.position
        }
    }

    /// Updates the video track's current format.
    ///
    /// - Parameter videoFormat: The new dimensions, frame rate, and encoding configuration.
    func updateVideoFormat(_ videoFormat: RealtimeVideoFormat) {
        metadataLock.withLock {
            metadata.videoFormat = videoFormat
        }
    }

    /// Updates the local camera track position.
    ///
    /// - Parameter position: The camera position currently used for capture.
    func updatePosition(_ position: CameraPosition) {
        metadataLock.withLock {
            metadata.position = position
        }
    }
}

private extension RealtimeVideoTrack {
    /// Stores video format and camera position metadata updated during capture and rendering.
    struct Metadata {

        /// Current media format
        var videoFormat: RealtimeVideoFormat?
        var position: CameraPosition?
        var device: CameraDevice?
    }
}
