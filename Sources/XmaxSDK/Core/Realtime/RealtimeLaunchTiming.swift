//
//  RealtimeLaunchTiming.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Realtime generation startup timing in milliseconds, using the same four stages as iOS performance logs.
///
/// Stages that have not completed are `nil`. Total timing begins when generation enters the business flow
/// and ends after the first frame is ready and generation state is committed, excluding camera preparation and extra render waits.
/// Total timing includes orchestration between stages and may differ from the sum of the four durations.
public struct RealtimeLaunchTiming: Equatable, Sendable {

    /// The time spent creating the server session.
    public let sessionMs: Double?

    /// The time from the RTC join call to a successful join.
    public let rtcJoinMs: Double?

    /// The time spent publishing local media streams.
    public let publishMs: Double?

    /// The time from sending the generation signal to the first displayable result frame.
    public let firstFrameMs: Double?

    /// The complete duration of this generation startup flow.
    public let totalMs: Double?

    /// Creates a startup timing snapshot with incomplete stages set to `nil`.
    ///
    /// - Parameters:
    ///   - sessionMs: Session creation time in milliseconds.
    ///   - rtcJoinMs: RTC join time in milliseconds.
    ///   - publishMs: Local stream publication time in milliseconds.
    ///   - firstFrameMs: Time from generation signal to the first frame, in milliseconds.
    ///   - totalMs: Total startup time in milliseconds.
    public init(
        sessionMs: Double? = nil,
        rtcJoinMs: Double? = nil,
        publishMs: Double? = nil,
        firstFrameMs: Double? = nil,
        totalMs: Double? = nil
    ) {
        self.sessionMs = sessionMs
        self.rtcJoinMs = rtcJoinMs
        self.publishMs = publishMs
        self.firstFrameMs = firstFrameMs
        self.totalMs = totalMs
    }
}

/// Main-thread startup timing callback; receives an empty snapshot for each new startup and updates as stages complete.
public typealias RealtimeLaunchTimingListener = @MainActor @Sendable (RealtimeLaunchTiming) -> Void
