//
//  RealtimePerformanceAlarm.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Realtime performance limitation state.
public enum RealtimePerformanceStatus: String, CaseIterable, Sendable {

    /// Device performance is limited; callers should consider the suggested video format.
    case limited = "Limited"

    /// Device performance has recovered.
    case recovered = "Recovered"
}

/// Realtime performance alarm information.
public struct RealtimePerformanceAlarm: Equatable, Sendable {

    /// Whether device performance is limited or recovered.
    public let status: RealtimePerformanceStatus

    /// The RTC-recommended fallback format; nil for invalid recommendations.
    public let suggestedVideoFormat: RealtimeVideoFormat?

    /// Creates realtime performance alarm information.
    ///
    /// - Parameters:
    ///   - status: The current device performance limitation state.
    ///   - suggestedVideoFormat: The suggested video format; `nil` without a valid recommendation.
    public init(
        status: RealtimePerformanceStatus,
        suggestedVideoFormat: RealtimeVideoFormat?
    ) {
        self.status = status
        self.suggestedVideoFormat = suggestedVideoFormat
    }
}

/// The realtime performance alarm listener.
public typealias RealtimePerformanceAlarmListener = @MainActor @Sendable (
    RealtimePerformanceAlarm
) -> Void
