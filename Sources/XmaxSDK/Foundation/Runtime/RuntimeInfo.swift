//
//  RuntimeInfo.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-macOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Darwin
import Foundation

/// 描述 SDK 当前运行环境。
struct RuntimeInfo: Encodable, Sendable {

    // 运行环境信息
    let platform: String
    let osVersion: String
    let sdkVersion: String
    let deviceModel: String

    // 当前环境快照
    static let current = RuntimeInfo(
        platform: "macos",
        osVersion: currentOSVersion(),
        sdkVersion: XmaxSDKInfo.version,
        deviceModel: currentDeviceModel()
    )

    /// 定义运行环境字段在请求中的编码名称。
    enum CodingKeys: String, CodingKey {
        case platform
        case osVersion = "os_version"
        case sdkVersion = "sdk_version"
        case deviceModel = "device_model"
    }
}

private extension RuntimeInfo {
    /// 读取当前操作系统版本并省略零补丁号。
    ///
    /// - Returns: 以点分隔的系统主版本、次版本和可选补丁版本。
    static func currentOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var components = [
            String(version.majorVersion),
            String(version.minorVersion)
        ]
        if version.patchVersion > 0 {
            components.append(String(version.patchVersion))
        }
        return components.joined(separator: ".")
    }

    /// 读取 Mac 硬件机型标识，无法读取时回退到系统架构。
    ///
    /// - Returns: 设备硬件标识；无法读取时返回 `unknown`。
    static func currentDeviceModel() -> String {
        var modelLength = 0
        if sysctlbyname("hw.model", nil, &modelLength, nil, 0) == 0, modelLength > 0 {
            var model = [CChar](repeating: 0, count: modelLength)
            if sysctlbyname("hw.model", &model, &modelLength, nil, 0) == 0 {
                return String(decoding: model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            }
        }

        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return "unknown"
        }
        let capacity = MemoryLayout.size(ofValue: systemInfo.machine)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: capacity
            ) { String(cString: $0) }
        }
    }
}
