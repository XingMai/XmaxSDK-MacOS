//
//  RealtimeSessionConnection.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// The RTC connection parameters for a realtime session.
struct RealtimeSessionConnection: Equatable, Sendable {

    /// Room connection parameters
    let roomID: String
    let userID: String
    let token: String
    let botName: String?
}

/// The realtime session heartbeat failure callback.
typealias RealtimeSessionHeartbeatFailureHandler = @Sendable (
    _ sessionID: String,
    _ error: XmaxError
) async -> Void
