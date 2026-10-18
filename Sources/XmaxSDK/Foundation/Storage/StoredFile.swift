//
//  StoredFile.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// The neutral result of an object storage upload.
struct StoredFile: Equatable, Sendable {

    /// Remote file information
    let url: URL
    let objectKey: String
    let etag: String?
}
