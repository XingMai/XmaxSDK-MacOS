//
//  CameraCaptureManaging.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-macOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// 管理系统摄像头及其原始视频帧输出。
protocol CameraCaptureManaging: Sendable {

    /// 查询当前可用的摄像头设备。
    ///
    /// - Returns: 包含设备标识、名称和默认状态的设备列表。
    func listCameraDevices() -> [CameraDevice]

    /// 启动指定设备，输出目标尺寸的 NV12 帧。
    ///
    /// - Parameters:
    ///   - videoFormat: 输出像素格式和尺寸。
    ///   - frameRate: 目标采集帧率。
    ///   - deviceID: 采集设备的标识。
    ///   - frameListener: 在采集串行队列接收视频帧。
    ///   - errorListener: 接收采集运行错误。
    /// - Throws: 设备、规格或采集启动失败时抛出错误。
    func start(
        videoFormat: VideoFormat,
        frameRate: Int,
        deviceID: String,
        frameListener: @escaping @Sendable (VideoFrame) throws -> Void,
        errorListener: @escaping XmaxErrorListener
    ) async throws

    /// 切换摄像头，保持输出尺寸和帧率。
    ///
    /// - Parameter deviceID: 目标设备标识。
    /// - Throws: 设备不可用或切换失败时抛出错误。
    func switchCamera(to deviceID: String) async throws

    /// 停止采集，等待正在处理的帧结束并释放设备。
    func stop() async
}
