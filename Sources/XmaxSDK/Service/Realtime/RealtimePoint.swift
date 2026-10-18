//
//  RealtimePoint.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// A normalized interaction point relative to processed media, from the top-left origin to `(1, 1)` at bottom right.
struct RealtimePoint: Equatable, Sendable {

    /// Normalized coordinates in [0, 1]
    let x: Double
    let y: Double
}
