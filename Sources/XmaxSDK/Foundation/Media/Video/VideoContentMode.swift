//
//  VideoContentMode.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// The video content display mode within its rendering container.
public enum VideoContentMode: String, CaseIterable, Sendable {

    /// Fits all content proportionally, allowing empty space.
    case fit

    /// Fills the container proportionally, allowing cropping.
    case fill
}
