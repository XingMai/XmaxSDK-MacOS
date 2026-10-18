//
//  MediaFrameListener.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Receives neutral video frames from the media layer.
typealias MediaVideoFrameListener = @Sendable (VideoFrame) throws -> Void

/// Receives neutral audio frames from the media layer.
typealias MediaAudioFrameListener = @Sendable (AudioFrame) throws -> Void
