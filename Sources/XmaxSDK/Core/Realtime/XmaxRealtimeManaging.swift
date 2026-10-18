//
//  XmaxRealtimeManaging.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// 定义 SDK 对接入方提供的实时媒体与生成控制能力。
public protocol XmaxRealtimeManaging: Sendable {

    /// 查询当前可用的摄像头设备，不启动采集。
    ///
    /// - Returns: 包含设备标识、名称和默认状态的设备列表。
    func listCameraDevices() async -> [CameraDevice]

    // 实时配置
    /// 实时能力配置。
    var options: RealtimeConfiguration { get }

    // 生命周期状态
    /// 当前实时连接与生成状态。
    var currentState: RealtimeState { get async }

    // 渲染状态
    /// 当前实际生效的远端视频插帧状态。
    var isFrameInterpolationEnabled: Bool { get async }

    // 音频状态

    /// 当前远端生成音频播放音量，取值范围为 `0...1`。
    /// 新建摄像头流后初始值为 0，可按需开启结果音频。
    var remoteAudioVolume: Float { get async }

    /// 设置实时状态监听器。
    ///
    /// - Parameter listener: 实时状态回调；传入 `nil` 时清除监听器。
    func setStateListener(
        _ listener: RealtimeStateListener?
    ) async

    /// 设置远端最终视频帧监听器。
    ///
    /// 监听器接收完成可选插帧处理、即将用于画面显示的视频帧。回调由 SDK
    /// 内部串行队列触发，不会阻塞主线程；调用方应快速转交帧数据，避免在
    /// 回调中执行耗时编码。传入 `nil` 时清除监听器。
    ///
    /// - Parameter listener: 远端最终视频帧回调。
    func setRemoteVideoFrameListener(
        _ listener: RealtimeVideoFrameListener?
    ) async

    /// 设置视频上行统计监听器。
    ///
    /// - Parameter listener: 主线程回调；未发布或断开连接时收到 nil；传入 nil 清除监听器。
    func setUplinkVideoStatisticsListener(_ listener: UplinkVideoStatisticsListener?) async

    /// 设置视频下行统计监听器。
    ///
    /// - Parameter listener: 主线程回调；结果流清理时收到 nil；传入 nil 清除监听器。
    func setDownlinkVideoStatisticsListener(_ listener: DownlinkVideoStatisticsListener?) async

    /// 设置网络质量监听器。
    ///
    /// - Parameter listener: 上下行网络质量回调；传入 `nil` 时清除监听器。
    func setNetworkQualityListener(
        _ listener: RealtimeNetworkQualityListener?
    ) async

    /// 设置设备性能告警监听器。
    ///
    /// - Parameter listener: 设备性能告警回调；传入 `nil` 时清除监听器。
    func setPerformanceAlarmListener(
        _ listener: RealtimePerformanceAlarmListener?
    ) async

    /// 设置远端生成音频播放音量。
    ///
    /// 尚未连接或订阅远端流时保存配置，并在远端音频开始播放前应用。
    /// 如需覆盖初始音量，请在创建本地流后调用。
    ///
    /// - Parameter volume: 远端播放音量，取值范围为 `0...1`。
    /// - Throws: 音量超出有效范围或 RTC 音量配置失败时抛出错误。
    func setRemoteAudioVolume(
        _ volume: Float
    ) async throws

    /// 开启或关闭远端生成画面的插帧。
    ///
    /// 设置结果覆盖初始化配置。生成中开启时请求等比例缩小回传尺寸，关闭时
    /// 请求恢复当前网络档位的回传尺寸；不会重新连接或重启生成。
    /// 尺寸切换期间继续显示原始帧。
    ///
    /// - Parameter enabled: 是否开启远端视频插帧。
    /// - Throws: 其他实时操作正在执行、设备或目标尺寸不支持插帧，或信令发送失败时抛出错误。
    func setFrameInterpolationEnabled(
        _ enabled: Bool
    ) async throws

    /// 创建本地相机流并开始预览。
    ///
    /// 将返回的轨道绑定到预览视图；收到有效帧且视图已绑定后进入 `ready`。
    ///
    /// - Parameters:
    ///   - videoFormat: 相机采集的视频规格。
    ///   - deviceID: 首次启用的设备标识；为空时使用系统默认摄像头。
    ///   - useMicrophone: 是否使用麦克风；创建时申请权限，连接时开始采集，断开时停止采集。
    /// - Returns: 包含本地相机视频轨道的媒体流。
    /// - Throws: 配置无效、所需权限被拒绝、操作冲突或采集启动失败时抛出错误。
    func createLocalCameraStream(
        videoFormat: RealtimeVideoFormat,
        deviceID: String?,
        useMicrophone: Bool
    ) async throws -> RealtimeMediaStream

    /// 停止本地相机流并更新媒体就绪状态。
    ///
    /// - Throws: 尚未断开实时连接、存在冲突操作或当前操作被取消时抛出错误。
    func stopLocalCameraStream() async throws

    /// 切换当前摄像头设备。
    ///
    /// 生成过程中调用时，SDK 会停止当前生成、切换摄像头，并使用缓存的生成
    /// 条件恢复生成；RTC 连接保持不变。连接或生成正在启动时不可切换。
    ///
    /// - Returns: 复用原视频轨道并更新摄像头位置后的本地媒体流。
    /// - Throws: 当前没有摄像头流、实时流程正在启动，或摄像头切换及生成恢复
    ///   失败时抛出错误。
    func switchCamera(to deviceID: String) async throws -> RealtimeMediaStream

    /// 使用当前 Manager 创建的本地流建立实时连接。
    ///
    /// - Parameter localStream: 当前 Manager 创建并持有的本地媒体流。
    /// - Returns: 当前连接的远端媒体流，可绑定到结果预览视图。
    /// - Throws: 本地流无效、连接已存在、操作冲突、取消或连接建立失败时抛出错误。
    func connect(
        localStream: RealtimeMediaStream
    ) async throws -> RealtimeMediaStream

    /// 断开实时连接并保留当前本地媒体预览。
    func disconnect() async

    /// 按指定业务原因断开实时连接，保留可用的本地媒体流。
    ///
    /// - Parameter reason: 本次断开的原因，例如显示方向变化。
    func disconnect(reason: RealtimeReason) async

    /// 关闭当前实时生命周期并释放连接、本地媒体和 RTC Engine。
    ///
    /// 关闭期间重复调用会等待同一个释放任务；关闭完成后仍可重新创建本地流。
    func close() async

    /// 开始生成，生成中再次调用时更新当前条件。
    ///
    /// - Parameters:
    ///   - context: 本次生成条件；首次生成不能为空，后续传入 `nil` 时复用缓存条件。
    ///   - faceRestoration: 是否回贴原始人脸；每次调用均发送本次设置。
    /// - Throws: 条件无效或生成启动、更新失败时抛出错误。
    func startGeneration(
        context: RealtimeContext?,
        faceRestoration: Bool
    ) async throws

    /// 使用当前本地流按需建立连接并开始生成。
    ///
    /// 已经连接时复用当前连接。返回的远端流可交给统一视频视图显示生成结果。
    ///
    /// - Parameters:
    ///   - localStream: 当前 Manager 创建并持有的本地媒体流。
    ///   - context: 本次生成条件；首次生成不能为空。
    ///   - faceRestoration: 是否回贴原始人脸；每次调用均发送本次设置。
    /// - Returns: 当前 RTC 连接对应的远端媒体流。
    /// - Throws: 本地流无效、连接失败或生成启动失败时抛出错误。
    func startGeneration(
        localStream: RealtimeMediaStream,
        context: RealtimeContext?,
        faceRestoration: Bool
    ) async throws -> RealtimeMediaStream
}
