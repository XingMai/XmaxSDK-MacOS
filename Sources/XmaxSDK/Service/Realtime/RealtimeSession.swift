//
//  RealtimeSession.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// An Xmax realtime generation session.
struct RealtimeSession: Equatable, Sendable {

    /// Session information
    let id: String
    let userID: String?
    let status: String?

    /// RTC connection
    let connection: RealtimeSessionConnection?

    /// Close reason
    let closeReason: String?
}
