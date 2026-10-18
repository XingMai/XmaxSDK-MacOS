//
//  MediaFileMetadata.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Video, audio, and timeline metadata for a local media file.
struct MediaFileMetadata: Equatable, Sendable {

    /// Video display format
    let width: Int
    let height: Int
    let rotation: VideoRotation

    /// Playback information
    let durationSeconds: Double
    let hasAudio: Bool
}
