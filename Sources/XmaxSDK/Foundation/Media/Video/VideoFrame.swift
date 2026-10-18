//
//  VideoFrame.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// A video frame retaining neutral pixel data and timing information.
struct VideoFrame: Equatable, Sendable {

    /// Buffer identity
    let bufferReuseID: UUID?

    /// Frame metadata
    let format: VideoFormat
    let timestampUs: Int64
    let rotation: VideoRotation

    /// Pixel data
    let planes: [VideoFramePlane]

    /// Creates a frame with pixel planes, timestamp, and display orientation.
    ///
    /// - Parameters:
    ///   - format: The video dimensions and pixel format.
    ///   - timestampUs: The frame timestamp in microseconds; must be nonnegative.
    ///   - planes: The pixel planes, containing at least one element.
    ///   - rotation: The rotation applied for display.
    ///   - bufferReuseID: The identifier permitting underlying buffer reuse; `nil` disables cache identity.
    /// - Throws: A configuration error for negative timestamps or empty pixel planes.
    init(
        format: VideoFormat,
        timestampUs: Int64,
        planes: [VideoFramePlane],
        rotation: VideoRotation = .rotation0,
        bufferReuseID: UUID? = nil
    ) throws {
        guard timestampUs >= 0 else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Video frame timestamp must be non-negative"
            )
        }
        guard !planes.isEmpty else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Video frame must contain at least one plane"
            )
        }

        self.bufferReuseID = bufferReuseID
        self.format = format
        self.timestampUs = timestampUs
        self.rotation = rotation
        self.planes = planes
    }

    /// Reuses pixel data to create a frame with a new timestamp and optional rotation.
    ///
    /// - Parameters:
    ///   - timestampUs: The new frame timestamp in microseconds.
    ///   - rotation: The new rotation; `nil` preserves the original.
    /// - Returns: A new frame sharing the original pixel planes and reuse identifier.
    /// - Throws: A configuration error if the new timestamp is invalid.
    func updating(
        timestampUs: Int64,
        rotation: VideoRotation? = nil
    ) throws -> VideoFrame {
        try VideoFrame(
            format: format,
            timestampUs: timestampUs,
            planes: planes,
            rotation: rotation ?? self.rotation,
            bufferReuseID: bufferReuseID
        )
    }
}
