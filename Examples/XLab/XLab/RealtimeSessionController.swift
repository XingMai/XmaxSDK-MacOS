//
//  RealtimeSessionController.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation
import XmaxSDK

/// 管理示例的会话生命周期、模式选择与参考图上传。
@MainActor
final class RealtimeSessionController: ObservableObject {

    // 用户配置
    @Published var apiKey = ""
    @Published var prompt = ""
    @Published var selectedDeviceID = ""
    @Published var model = RealtimeModel.x2_1_1_preview_cn
    @Published var activeMode = RealtimeExampleMode.charx

    // 显示状态
    @Published private(set) var devices: [CameraDevice] = []
    @Published private(set) var localStream: RealtimeMediaStream?
    @Published private(set) var remoteStream: RealtimeMediaStream?
    @Published private(set) var state = RealtimeState(connectionState: .idle)
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var sessionStartedAt: Date?
    @Published private(set) var selectedReferenceID: String?
    @Published private(set) var uploadedReferences: [RealtimeReference] = []
    @Published private(set) var uploadProgress: Double?

    // SDK 资源与操作归属
    private var client: XmaxClient?
    private var manager: (any XmaxRealtimeManaging)?
    private var lifecycleID = UUID()
    private var pendingInitialReference: RealtimeReference?

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canGenerate: Bool {
        hasAPIKey && !isBusy && localStream != nil &&
            [.ready, .connected, .generating].contains(state.connectionState)
    }

    var freeReference: RealtimeReference? {
        uploadedReferences.last { $0.mode == .free }
    }

    /// 查询设备，不启动摄像头或建立服务端会话。
    func refreshDevices() async {
        let client = XmaxClient(configuration: XmaxConfiguration(apiKey: ""))
        let discovery = client.createRealtimeManager(options: RealtimeConfiguration(model: model))
        devices = await discovery.listCameraDevices()
        await discovery.close()
    }

    /// 开启摄像头；一键生成模式在有效帧和预览绑定就绪后提交首个预设。
    func startPreview(autoGenerate: Bool = false) async {
        guard !isBusy, localStream == nil else { return }
        guard !autoGenerate || hasAPIKey else {
            errorMessage = "请先点击右上角的钥匙，填写 API Key。"
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        let operation = UUID()
        lifecycleID = operation
        let client = XmaxClient(configuration: XmaxConfiguration(apiKey: apiKey))
        let manager = client.createRealtimeManager(options: RealtimeConfiguration(model: model))
        self.client = client
        self.manager = manager
        selectedReferenceID = nil
        activeMode = .charx
        await manager.setStateListener { [weak self] state in
            guard let self, self.lifecycleID == operation else { return }
            self.state = state
            if case let .failure(error) = state.reason {
                self.errorMessage = error.message
                self.pendingInitialReference = nil
            }
            if state.connectionState == .ready || state.connectionState == .idle {
                self.remoteStream = nil
            }
            if state.connectionState == .idle {
                self.localStream = nil
                self.sessionStartedAt = nil
            }
            if state.connectionState == .ready {
                Task { [weak self] in await self?.startPendingGeneration() }
            }
        }
        pendingInitialReference = autoGenerate ? RealtimeExampleMode.charx.presets.first : nil
        do {
            let stream = try await manager.createLocalCameraStream(
                deviceID: selectedDeviceID.isEmpty ? nil : selectedDeviceID
            )
            guard lifecycleID == operation else { await manager.close(); return }
            localStream = stream
            sessionStartedAt = Date()
        } catch {
            guard lifecycleID == operation else { return }
            errorMessage = error.localizedDescription
            pendingInitialReference = nil
            await manager.close()
            self.manager = nil
            self.client = nil
        }
    }

    /// 选择预设即更新生成；切换模式页签本身不提交请求。
    func selectReference(_ reference: RealtimeReference) async {
        guard canGenerate else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await generate(
                context: RealtimeContext(prompt: reference.mode == .free ? prompt : reference.mode.prompt,
                                         referencePath: reference.referencePath),
                mode: reference.mode,
                selectedReferenceID: reference.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 使用自由输入页的文本和可选上传参考图开始或更新生成。
    func submitPrompt() async {
        guard canGenerate else { return }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || freeReference != nil else {
            errorMessage = "请先输入生成描述或上传一张参考图。"
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await generate(
                context: RealtimeContext(prompt: prompt, referencePath: freeReference?.referencePath),
                mode: .free,
                selectedReferenceID: freeReference?.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 上传用户通过文件选择器指定的参考图，并复用普通选图的生成语义。
    func uploadReference(at fileURL: URL, mode: RealtimeExampleMode) async {
        guard canGenerate, let client else { return }
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        let operation = lifecycleID
        isBusy = true
        uploadProgress = 0
        errorMessage = nil
        defer { isBusy = false; uploadProgress = nil }
        do {
            let storage = try client.createStorageManager()
            let file = try await storage.uploadImage(at: fileURL, contentType: nil) { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    guard let self, self.lifecycleID == operation else { return }
                    self.uploadProgress = fraction
                }
            }
            guard lifecycleID == operation else { return }
            let reference = RealtimeReference(
                id: UUID().uuidString, mode: mode,
                name: fileURL.deletingPathExtension().lastPathComponent,
                thumbnailURL: file.url, referencePath: file.url.absoluteString
            )
            if mode == .free { uploadedReferences.removeAll { $0.mode == .free } }
            uploadedReferences.append(reference)
            uploadProgress = nil
            try await generate(
                context: RealtimeContext(prompt: mode == .free ? prompt : mode.prompt, referencePath: reference.referencePath),
                mode: mode,
                selectedReferenceID: reference.id
            )
        } catch {
            guard lifecycleID == operation else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// 移除自由输入页的参考图，下一次提交时生效。
    func removeFreeReference() {
        guard !isBusy else { return }
        if selectedReferenceID == freeReference?.id { selectedReferenceID = nil }
        uploadedReferences.removeAll { $0.mode == .free }
    }

    func dismissError() { errorMessage = nil }

    /// 结束会话并返回启动页，释放摄像头与 RTC 资源。
    func close() async {
        guard !isBusy else { return }
        isBusy = true
        pendingInitialReference = nil
        defer { isBusy = false }
        await manager?.close()
        lifecycleID = UUID()
        manager = nil
        client = nil
        localStream = nil
        remoteStream = nil
        sessionStartedAt = nil
        selectedReferenceID = nil
        errorMessage = nil
    }

    /// 界面移除后撤销操作归属并释放资源。
    func viewDidDisappear() {
        lifecycleID = UUID()
        pendingInitialReference = nil
        let manager = manager
        self.manager = nil
        client = nil
        Task { await manager?.close() }
    }

    /// 只消费一次自动生成请求，避免 ready 状态恢复后重复提交。
    private func startPendingGeneration() async {
        guard canGenerate, let reference = pendingInitialReference else { return }
        pendingInitialReference = nil
        await selectReference(reference)
    }

    /// 所有条件更新共用入口，换装模式沿用 Web 的人脸还原设置。
    private func generate(
        context: RealtimeContext,
        mode: RealtimeExampleMode,
        selectedReferenceID: String?
    ) async throws {
        guard let manager, let localStream else { return }
        let operation = lifecycleID
        let remote = try await manager.startGeneration(
            localStream: localStream, context: context, faceRestoration: mode.faceRestoration
        )
        guard lifecycleID == operation else { return }
        remoteStream = remote
        self.selectedReferenceID = selectedReferenceID
    }
}
