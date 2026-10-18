//
//  EncodingController.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Configures RTC encoding from the realtime video format.
final class EncodingController: EncodingControlling, Sendable {

    /// Foundation components
    private let rtcManager: any RtcManaging

    /// Creates a controller applying RTC video encoding configuration.
    ///
    /// - Parameter rtcManager: The RTC manager receiving encoding configuration.
    init(rtcManager: any RtcManaging) {
        self.rtcManager = rtcManager
    }

    /// Validates video format and applies resolved RTC encoding parameters.
    ///
    /// - Parameter videoFormat: The format containing dimensions, frame rate, optional bitrate, and encoding preferences.
    /// - Throws: An error on invalid format, default bitrate resolution failure, or RTC configuration failure.
    func configure(_ videoFormat: RealtimeVideoFormat) throws {
        try videoFormat.validate()

        let (minimum, maximum) = try EncodingBitratePolicy.resolve(videoFormat)

        let encoderPreference: VideoEncodingConfiguration.EncoderPreference = switch videoFormat.encoderPreference {
            case .auto: .auto
            case .maintainFramerate: .maintainFramerate
            case .maintainQuality: .maintainQuality
        }

        try rtcManager.configureVideoEncoding(
            VideoEncodingConfiguration(
                width: videoFormat.width,
                height: videoFormat.height,
                frameRate: videoFormat.fps,
                minimumBitrate: minimum,
                maximumBitrate: maximum,
                encoderPreference: encoderPreference
            )
        )
    }
}
