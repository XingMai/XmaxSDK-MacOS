//
//  InteractionFrame.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import CoreGraphics

/// An interaction sample captured from a render viewport.
struct InteractionFrame: Sendable {

    /// Touch sample
    let points: [CGPoint]

    /// Display mapping
    let viewportSize: CGSize
    let contentMode: VideoContentMode
    var displayedVideoSize: CGSize? = nil
}

extension RealtimeVideoFormat {

    /// Pixel dimensions
    var size: CGSize {
        CGSize(width: width, height: height)
    }
}
