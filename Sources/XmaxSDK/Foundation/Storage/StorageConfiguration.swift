//
//  StorageConfiguration.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// The endpoint, bucket, and temporary credentials for object storage requests.
struct StorageConfiguration: Equatable, Sendable {

    /// Storage location
    let bucket: String
    let region: String
    let endpoint: String

    /// Access credentials
    let credential: StorageCredential
}
