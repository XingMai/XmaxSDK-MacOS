//
//  RuntimeInfo.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Darwin
import Foundation

/// Describes the current SDK runtime environment.
struct RuntimeInfo: Encodable, Sendable {

    /// Runtime environment information
    let platform: String
    let osVersion: String
    let sdkVersion: String
    let deviceModel: String

    /// Current environment snapshot
    static let current = RuntimeInfo(
        platform: "macos",
        osVersion: currentOSVersion(),
        sdkVersion: XmaxSDKInfo.version,
        deviceModel: currentDeviceModel()
    )

    /// Defines request encoding names for runtime environment fields.
    enum CodingKeys: String, CodingKey {
        case platform
        case osVersion = "os_version"
        case sdkVersion = "sdk_version"
        case deviceModel = "device_model"
    }
}

private extension RuntimeInfo {
    /// Reads the operating system version, omitting a zero patch version.
    ///
    /// - Returns: The dot-separated major, minor, and optional patch version.
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

    /// Reads the Mac hardware model identifier, falling back to system architecture.
    ///
    /// - Returns: The hardware identifier, or `unknown` if unavailable.
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
