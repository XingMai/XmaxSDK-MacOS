//
//  RealtimeMediaSource.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Local media sources supported by a realtime generation model.
public enum RealtimeMediaSource: String, CaseIterable, Sendable {

    /// Camera
    case camera

    /// Caller-owned video input
    case external

    /// Video
    case video

    /// Image
    case image
}
