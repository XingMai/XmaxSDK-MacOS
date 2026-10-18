//
//  MediaControlling.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-macOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// 定义媒体层向 Core 暴露的统一能力。
protocol MediaControlling: Actor, InteractionControlling {

    /// 查询当前可用的摄像头设备，不启动采集。
    ///
    /// - Returns: 包含设备标识、名称和默认状态的设备列表。
    func listCameraDevices() -> [CameraDevice]

    // 本地媒体状态
    /// 当前活动的本地视频轨道。
    var currentTrack: RealtimeVideoTrack? { get }

    /// 当前本地视频格式。
    var currentVideoFormat: RealtimeVideoFormat? { get }

    /// 是否为媒体保留比例并使用独立生成画布；摄像头为 false。
    var usesContainPadding: Bool { get }

    /// 当前媒体来源是否包含由 SDK 管理的本地音频。
    var hasAudio: Bool { get }

    /// 设置当前相机流的一次性内部就绪处理。
    ///
    /// - Parameter handler: 收到有效帧且预览已绑定时调用；传入空值时清除。
    func setCameraPreviewReadyHandler(_ handler: CameraPreviewReadyHandler?)

    /// 创建并持有本地相机媒体流，同时启动采集和本地预览。
    ///
    /// - Parameters:
    ///   - videoFormat: 相机采集使用的目标视频格式。
    ///   - deviceID: 首次启用的设备标识；为空时使用系统默认摄像头。
    ///   - useMicrophone: 是否使用麦克风；创建时检查权限，连接时启动采集。
    /// - Returns: 包含本地相机视频轨道的媒体流。
    /// - Throws: 相机权限、RTC 初始化或采集启动失败时抛出错误；
    ///   已有活动媒体来源时也会失败。
    func createLocalCameraStream(
        videoFormat: RealtimeVideoFormat,
        deviceID: String?,
        useMicrophone: Bool
    ) async throws -> RealtimeMediaStream

    /// 为启用了麦克风的相机流启动内部音频采集；其他来源不受影响。
    ///
    /// - Throws: 操作被取消或 RTC 音频采集启动失败时抛出错误。
    func startMicrophoneCapture() throws

    /// 停止相机流的麦克风采集，保留相机预览和麦克风配置。
    ///
    /// - Throws: RTC 音频采集停止失败时抛出错误。
    func stopMicrophoneCapture() throws

    /// 停止并释放当前本地相机媒体流、预览绑定和 RTC 资源；
    /// 当前来源不是相机时忽略。
    func stopLocalCameraStream() async

    /// 切换到指定摄像头设备，保留当前视频轨道。
    ///
    /// - Returns: 包含更新后摄像头位置的本地媒体流。
    /// - Throws: 当前来源不是相机、存在并发媒体操作或摄像头切换失败时抛出错误。
    func switchCamera(to deviceID: String) async throws -> RealtimeMediaStream

    /// 停止并释放当前本地媒体流、预览绑定和 RTC Engine；
    /// 没有活动来源时忽略。
    func stopLocalStream() async

    /// 判断指定媒体流是否由当前活动媒体来源持有。
    ///
    /// - Parameter stream: 需要验证所有权的媒体流。
    /// - Returns: 媒体流的视频轨道由当前活动来源持有时返回 `true`，
    ///   否则返回 `false`。
    func owns(_ stream: RealtimeMediaStream) -> Bool
}
