//
//  DownloadedFile.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// The neutral result of a completed remote file download.
struct DownloadedFile: Equatable, Sendable {

    /// Local file information
    let fileURL: URL
    let byteCount: Int64
}
