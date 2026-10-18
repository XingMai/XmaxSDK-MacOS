//
//  RealtimeMediaStream.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// A realtime stream containing local input or remote generated results.
public struct RealtimeMediaStream: Sendable {

    /// The media stream identifier.
    public let id: String

    /// The stream's video track.
    public let videoTrack: RealtimeVideoTrack?
}
