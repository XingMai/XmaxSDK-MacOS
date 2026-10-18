//
//  RemoteStream.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Identifies a remote primary stream in an RTC room.
struct RemoteStream: Equatable, Hashable, Sendable {

    /// Stream identity
    let roomID: String
    let userID: String

    /// Creates a remote stream key unique across rooms.
    var key: String {
        "\(roomID):\(userID)"
    }
}
