//
//  VideoPixelFormat.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Pixel formats supported by neutral video frames.
enum VideoPixelFormat: String, CaseIterable, Sendable {
    case i420
    case nv12
    case nv21
    case rgba
    case bgra
    case argb
}
