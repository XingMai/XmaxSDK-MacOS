//
//  XmaxEnvironment.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// The Xmax service environment.
public enum XmaxEnvironment: String, CaseIterable, Equatable, Sendable {

    /// The domestic environment.
    case china

    /// The overseas environment.
    case global
}

extension XmaxEnvironment {

    /// The general API URL for this environment.
    var apiBaseURL: URL {
        switch self {
        case .china:
            URL(string: "https://cloud.xmax.22duck.cn/open/api/v1")!
        case .global:
            URL(string: "https://api.xmax.cloud/open/api/v1")!
        }
    }
}
