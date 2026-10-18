//
//  StorageCredential.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Temporary credentials for one object storage request.
struct StorageCredential: Equatable, Sendable {

    /// Temporary access credentials
    let accessKeyID: String
    let secretAccessKey: String
    let sessionToken: String
}
