//
//  XmaxUploadedFile.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// A successfully uploaded remote file.
public struct XmaxUploadedFile: Equatable, Sendable {

    /// The remote file URL.
    public let url: URL

    /// The file identifier in object storage.
    public let objectKey: String

    /// The optional entity tag returned by object storage.
    public let etag: String?

    /// Creates an upload result.
    ///
    /// - Parameters:
    ///   - url: The remote URL of the uploaded file.
    ///   - objectKey: The file identifier in object storage.
    ///   - etag: The entity tag returned by object storage, or nil if absent.
    init(url: URL, objectKey: String, etag: String?) {
        self.url = url
        self.objectKey = objectKey
        self.etag = etag
    }
}
