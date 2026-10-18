//
//  RealtimeSessionController.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation
import XmaxSDK

/// 管理示例界面使用的摄像头预览及实时生成生命周期。
@MainActor
final class RealtimeSessionController: ObservableObject {

    // 用户配置
    @Published var apiKey = ""
    @Published var prompt = "让画面呈现电影质感"
    @Published var referencePath = ""
    @Published var selectedDeviceID = ""
    @Published var model = RealtimeModel.x2_1_1_preview_cn

    // 显示状态
    @Published private(set) var devices: [CameraDevice] = []
    @Published private(set) var localStream: RealtimeMediaStream?
    @Published private(set) var remoteStream: RealtimeMediaStream?
    @Published private(set) var state = RealtimeState(connectionState: .idle)
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false

    // SDK 资源
    private var manager: (any XmaxRealtimeManaging)?

    /// 查询设备，不启动摄像头或建立服务端会话。
    func refreshDevices() async {
        let client = XmaxClient(configuration: XmaxConfiguration(apiKey: ""))
        let discovery = client.createRealtimeManager(options: RealtimeConfiguration(model: model))
        devices = await discovery.listCameraDevices()
        await discovery.close()
    }

    /// 使用当前配置启动预览，并将返回的本地轨道交给视频视图。
    func startPreview() async {
        guard !isBusy, localStream == nil else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        let client = XmaxClient(configuration: XmaxConfiguration(apiKey: apiKey))
        let manager = client.createRealtimeManager(options: RealtimeConfiguration(model: model))
        self.manager = manager
        await manager.setStateListener { [weak self] state in
            self?.state = state
            if case let .failure(error) = state.reason {
                self?.errorMessage = error.message
            }
            if state.connectionState == .ready || state.connectionState == .idle {
                self?.remoteStream = nil
            }
            if state.connectionState == .idle { self?.localStream = nil }
        }
        do {
            localStream = try await manager.createLocalCameraStream(
                deviceID: selectedDeviceID.isEmpty ? nil : selectedDeviceID
            )
        } catch {
            errorMessage = error.localizedDescription
            await manager.close()
            self.manager = nil
        }
    }

    /// 使用当前提示词及可选参考图路径开始或更新生成。
    func startGeneration() async {
        guard !isBusy, let manager, let localStream else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            remoteStream = try await manager.startGeneration(
                localStream: localStream,
                context: RealtimeContext(prompt: prompt, referencePath: referencePath)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 断开生成连接，保留摄像头预览。
    func disconnect() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await manager?.disconnect()
        remoteStream = nil
    }

    /// 释放当前生命周期，允许重新配置凭证和设备。
    func close() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await manager?.close()
        manager = nil
        localStream = nil
        remoteStream = nil
    }

    /// 界面移除后释放资源，不依赖界面任务是否已取消。
    func viewDidDisappear() {
        let manager = manager
        self.manager = nil
        Task { await manager?.close() }
    }
}
