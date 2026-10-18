//
//  VideoEncodingConfiguration.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// RTC primary video stream encoding parameters.
struct VideoEncodingConfiguration: Equatable, Sendable {
    /// Defines video encoding degradation preferences under limited network conditions.
    enum EncoderPreference: Equatable, Sendable {
        case auto
        case maintainFramerate
        case maintainQuality
    }

    /// Video format
    let width: Int
    let height: Int
    let frameRate: Int

    /// Bitrate and encoding strategy
    let minimumBitrate: Int
    let maximumBitrate: Int
    let encoderPreference: EncoderPreference

    /// Creates RTC video encoding configuration.
    ///
    /// - Parameters:
    ///   - width: The encoding width in pixels.
    ///   - height: The encoding height in pixels.
    ///   - frameRate: The encoding frame rate in fps.
    ///   - minimumBitrate: The minimum bitrate in kbps; the platform handles the default.
    ///   - maximumBitrate: The maximum bitrate in kbps; negative values use the platform default.
    ///   - encoderPreference: The encoding preference under limited network conditions.
    init(
        width: Int,
        height: Int,
        frameRate: Int,
        minimumBitrate: Int = 0,
        maximumBitrate: Int = -1,
        encoderPreference: EncoderPreference = .maintainFramerate
    ) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.minimumBitrate = minimumBitrate
        self.maximumBitrate = maximumBitrate
        self.encoderPreference = encoderPreference
    }
}
