//
//  StorageUploadSource.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Binary data or a local file supported by object storage uploads.
enum StorageUploadSource: Equatable, Sendable {
    case data(Data)
    case file(URL)
}
