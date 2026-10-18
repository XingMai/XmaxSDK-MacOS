//
//  StorageProgressListener.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// The storage progress callback receiving completed and total byte counts.
typealias StorageProgressListener = @Sendable (
    _ completedBytes: Int64,
    _ totalBytes: Int64
) -> Void
