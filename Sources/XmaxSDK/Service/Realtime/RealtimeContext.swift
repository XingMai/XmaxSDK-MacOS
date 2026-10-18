//
//  RealtimeContext.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Text and reference context for one realtime generation task.
public struct RealtimeContext: Equatable, Sendable {

    /// The realtime generation text prompt.
    public let prompt: String

    /// The optional remote path of an uploaded reference image.
    public let referencePath: String?

    /// Creates generation conditions and trims the prompt and reference path.
    ///
    /// - Parameters:
    ///   - prompt: The realtime generation text prompt.
    ///   - referencePath: The reference image remote path; `nil` or whitespace omits the image.
    public init(
        prompt: String,
        referencePath: String? = nil
    ) {
        self.prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReferencePath = referencePath?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        self.referencePath = normalizedReferencePath?.isEmpty == false
            ? normalizedReferencePath
            : nil
    }
}
