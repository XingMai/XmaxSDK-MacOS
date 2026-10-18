//
//  XmaxStorageProgressHandler.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Receives file upload or download progress.
///
/// - Parameter progress: Progress containing completed and total byte counts.
public typealias XmaxStorageProgressHandler = @Sendable (Progress) -> Void
