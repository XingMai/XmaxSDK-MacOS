//
//  XmaxDownloadedFile.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// A file downloaded to local storage.
public struct XmaxDownloadedFile: Equatable, Sendable {

    /// The downloaded local file URL.
    public let fileURL: URL

    /// The downloaded file size in bytes.
    public let byteCount: Int64

    /// Creates a download result.
    ///
    /// - Parameters:
    ///   - fileURL: The local file URL after download completes.
    ///   - byteCount: The local file size in bytes.
    init(fileURL: URL, byteCount: Int64) {
        self.fileURL = fileURL
        self.byteCount = byteCount
    }
}
