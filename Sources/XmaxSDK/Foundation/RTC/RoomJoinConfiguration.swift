//
//  RoomJoinConfiguration.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// RTC room join parameters.
struct RoomJoinConfiguration: Equatable, Sendable {

    /// Room connection parameters
    let roomID: String
    let userID: String
    let token: String
}
