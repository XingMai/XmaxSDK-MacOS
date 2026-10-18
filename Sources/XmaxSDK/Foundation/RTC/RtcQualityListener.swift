//
//  RtcQualityListener.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Neutral RTC network quality levels.
enum RtcQualityLevel: Int, CaseIterable, Sendable {
    case unknown
    case excellent
    case good
    case poor
    case bad
    case veryBad
    case down
}

/// Receives RTC network quality and performance fallback events.
protocol RtcQualityListener: AnyObject {

    /// Receives local upstream video statistics.
    ///
    /// - Parameter statistics: The upstream metrics for this reporting interval.
    @MainActor
    func onUplinkVideoStatistics(_ statistics: UplinkVideoStatistics)

    /// Receives remote downstream video statistics.
    ///
    /// - Parameter statistics: The downstream metrics for this reporting interval.
    @MainActor
    func onDownlinkVideoStatistics(_ statistics: DownlinkVideoStatistics)

    /// Receives realtime upstream and downstream network quality.
    ///
    /// - Parameters:
    ///   - uplink: The local sending network quality.
    ///   - downlink: The remote receiving network quality.
    @MainActor
    func onNetworkQuality(
        uplink: RtcQualityLevel,
        downlink: RtcQualityLevel
    )

    /// Receives performance limitation or recovery events.
    ///
    /// - Parameters:
    ///   - limited: Whether performance is currently limited.
    ///   - suggestedWidth: The suggested video width in pixels.
    ///   - suggestedHeight: The suggested video height in pixels.
    ///   - suggestedFrameRate: The suggested video frame rate in fps.
    @MainActor
    func onPerformanceAlarm(
        limited: Bool,
        suggestedWidth: Int,
        suggestedHeight: Int,
        suggestedFrameRate: Int
    )
}
