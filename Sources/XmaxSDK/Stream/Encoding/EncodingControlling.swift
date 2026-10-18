//
//  EncodingControlling.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Defines realtime video encoding configuration capabilities.
protocol EncodingControlling: Sendable {

    /// Validates video format and applies resolved RTC encoding parameters.
    ///
    /// - Parameter videoFormat: The format containing dimensions, frame rate, optional bitrate, and encoding preferences.
    /// - Throws: An error on invalid format, default bitrate resolution failure, or RTC configuration failure.
    func configure(_ videoFormat: RealtimeVideoFormat) throws
}
