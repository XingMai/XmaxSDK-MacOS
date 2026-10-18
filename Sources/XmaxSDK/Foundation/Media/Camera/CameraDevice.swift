//
//  CameraDevice.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// 描述当前可用的 macOS 摄像头，不持有系统采集资源。
public struct CameraDevice: Identifiable, Equatable, Sendable {

    // 设备信息
    /// 系统分配的设备标识，可用于创建或切换摄像头流。
    public let id: String

    /// 系统提供的设备显示名称。
    public let name: String

    /// 当前设备是否为系统默认摄像头。
    public let isDefault: Bool

    /// 系统报告的摄像头位置；外接设备可能没有方向信息。
    public let position: CameraPosition
}
