//
//  RealtimeSessionController.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import CoreGraphics
import Foundation
import ImageIO
import XmaxSDK

/// 管理示例的会话生命周期、模式选择与参考图上传。
@MainActor
final class RealtimeSessionController: ObservableObject {

    // 用户配置：与 Web 的 localStorage 一致，保存在当前用户的应用设置中。
    @Published var apiKey = UserDefaults.standard.string(forKey: "xmax.xlab.apiKey") ?? "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: "xmax.xlab.apiKey") }
    }
    @Published var prompt = ""
    @Published var model = RealtimeModel.x2_1_1_preview_cn
    @Published var useMicrophone = false
    @Published var statisticsVisible = true
    @Published var activeMode = RealtimeExampleMode.charx {
        didSet {
            selectionIntent = UUID()
            errorMessage = nil
        }
    }

    // 显示状态
    @Published private(set) var sessionActive = false
    @Published private(set) var localStream: RealtimeMediaStream?
    @Published private(set) var remoteStream: RealtimeMediaStream?
    @Published private(set) var state = RealtimeState(connectionState: .idle)
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var sessionStartedAt: Date?
    @Published private(set) var selectedReferenceID: String?
    @Published private(set) var uploadedReferences: [RealtimeReference] = []
    @Published private(set) var uplinkStatistics: UplinkVideoStatistics?
    @Published private(set) var downlinkStatistics: DownlinkVideoStatistics?
    @Published private(set) var networkQuality: RealtimeNetworkQuality?
    @Published private(set) var interpolationEnabled = false
    @Published private(set) var interpolationSwitching = false
    @Published private(set) var remoteAudioVolume: Float = 0

    // SDK 资源与操作归属
    private var client: XmaxClient?
    private var manager: (any XmaxRealtimeManaging)?
    private var lifecycleID = UUID()
    private var selectionIntent = UUID()
    private var pendingInitialReference: RealtimeReference?
    private var application: Task<Void, Never>?
    private let makeManager: (XmaxClient, RealtimeConfiguration) -> any XmaxRealtimeManaging
    private let uploadImage: (XmaxClient, Data, String, XmaxStorageProgressHandler?) async throws -> URL

    init(
        makeManager: @escaping (XmaxClient, RealtimeConfiguration) -> any XmaxRealtimeManaging = {
            $0.createRealtimeManager(options: $1)
        },
        uploadImage: @escaping (XmaxClient, Data, String, XmaxStorageProgressHandler?) async throws -> URL = {
            client, data, name, progress in
            let storage = try client.createStorageManager()
            return try await storage.uploadImage(data, fileName: name, contentType: "image/jpeg", progress: progress).url
        }
    ) {
        self.makeManager = makeManager
        self.uploadImage = uploadImage
    }

    var hasAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canGenerate: Bool { hasAPIKey && !isBusy && sessionActive }
    var freeReference: RealtimeReference? { uploadedReferences.first { $0.mode == .free } }
    var referenceUploading: Bool {
        uploadedReferences.contains { $0.mode == activeMode && $0.uploadState == .uploading }
    }

    /// 启动中保持启动页；本地预览先在页面背景挂载，满足 SDK 的媒体就绪条件。
    func start() async {
        guard !isBusy, localStream == nil else { return }
        guard hasAPIKey else {
            errorMessage = "API Key is required — click the key button in the top-right corner to enter it"
            return
        }
        isBusy = true
        errorMessage = nil
        let operation = UUID()
        lifecycleID = operation
        activeMode = .charx
        selectedReferenceID = nil
        uplinkStatistics = nil
        downlinkStatistics = nil
        networkQuality = nil
        let client = XmaxClient(configuration: XmaxConfiguration(apiKey: apiKey))
        let manager = makeManager(client, RealtimeConfiguration(
            model: model, isFrameInterpolationEnabled: interpolationEnabled
        ))
        self.client = client
        self.manager = manager
        await manager.setUplinkVideoStatisticsListener { [weak self] statistics in
            guard let self, self.lifecycleID == operation else { return }
            self.uplinkStatistics = statistics
        }
        await manager.setDownlinkVideoStatisticsListener { [weak self] statistics in
            guard let self, self.lifecycleID == operation else { return }
            self.downlinkStatistics = statistics
        }
        await manager.setNetworkQualityListener { [weak self] quality in
            guard let self, self.lifecycleID == operation else { return }
            self.networkQuality = quality
        }
        await manager.setStateListener { [weak self] state in
            guard let self, self.lifecycleID == operation else { return }
            self.state = state
            if [.connected, .generating].contains(state.connectionState), !self.sessionActive {
                self.sessionActive = true
                self.sessionStartedAt = Date()
            }
            if ![.connected, .generating].contains(state.connectionState) { self.remoteStream = nil }
            if case let .failure(error) = state.reason {
                self.errorMessage = error.message
                if !self.sessionActive {
                    let failedManager = self.manager
                    self.pendingInitialReference = nil
                    self.resetSession()
                    Task { await failedManager?.close() }
                }
            }
            if state.connectionState == .ready {
                Task { [weak self] in await self?.startPendingGeneration() }
            }
        }
        pendingInitialReference = RealtimeExampleMode.charx.presets.first
        do {
            let stream = try await manager.createLocalCameraStream(useMicrophone: useMicrophone)
            guard lifecycleID == operation else { await manager.close(); return }
            localStream = stream
            try await manager.setRemoteAudioVolume(remoteAudioVolume)
            await startPendingGeneration()
        } catch {
            guard lifecycleID == operation else { return }
            errorMessage = error.localizedDescription
            resetSession()
            await manager.close()
        }
    }

    /// 只消费一次初始预设；生成连接成功前不切换页面，失败则释放摄像头。
    private func startPendingGeneration() async {
        guard state.connectionState == .ready, localStream != nil,
              let reference = pendingInitialReference else { return }
        pendingInitialReference = nil
        let operation = lifecycleID
        do {
            selectedReferenceID = reference.id
            try await generate(reference: reference)
        } catch {
            guard lifecycleID == operation else { return }
            errorMessage = error.localizedDescription
            if !sessionActive {
                let manager = manager
                resetSession()
                await manager?.close()
            }
        }
        if lifecycleID == operation { isBusy = false }
    }

    /// 条件更新不锁住整个页面；连续选择串行应用，只保留最新的待处理选择。
    func selectReference(_ reference: RealtimeReference) async {
        guard canGenerate, reference.uploadState != .uploading else { return }
        let intent = UUID()
        selectionIntent = intent
        if reference.uploadState == .error {
            await upload(reference: reference, intent: intent)
        } else {
            await enqueue(reference: reference, intent: intent)
        }
    }

    /// 自由输入与选图复用生成队列，切换页签本身不重新生成。
    func submitPrompt() async {
        guard canGenerate, !referenceUploading else { return }
        let reference = RealtimeReference(
            id: freeReference?.id ?? UUID().uuidString, mode: .free, name: "",
            thumbnailURL: freeReference?.thumbnailURL ?? URL(fileURLWithPath: "/"),
            referencePath: freeReference?.referencePath ?? "", prompt: prompt
        )
        let intent = UUID()
        selectionIntent = intent
        await enqueue(reference: reference, intent: intent)
    }

    /// 本地文件立即插入列表首位；上传进度和重试状态属于条目，不锁定其他控件。
    func uploadReference(at fileURL: URL, mode: RealtimeExampleMode) async {
        guard canGenerate else { return }
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let reference = RealtimeReference(
                id: UUID().uuidString, mode: mode, name: fileURL.lastPathComponent,
                thumbnailURL: fileURL, referencePath: "", thumbnailData: data,
                prompt: mode == .free ? prompt : mode.prompt
            )
            uploadedReferences.insert(reference, at: 0)
            let intent = UUID()
            selectionIntent = intent
            await upload(reference: reference, intent: intent)
        } catch { errorMessage = error.localizedDescription }
    }

    private func upload(reference: RealtimeReference, intent: UUID) async {
        guard let client, let data = reference.thumbnailData else { return }
        let operation = lifecycleID
        patchReference(reference.id) { $0.uploadState = .uploading; $0.uploadError = nil; $0.uploadProgress = 0 }
        errorMessage = nil
        do {
            let jpeg = try await Task.detached { try Self.jpegData(data) }.value
            let uploadedURL = try await uploadImage(
                client, jpeg, (reference.name as NSString).deletingPathExtension + ".jpg"
            ) { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor in
                    guard let self else { return }
                    self.patchReference(reference.id) { $0.uploadProgress = fraction }
                }
            }
            patchReference(reference.id) {
                $0.referencePath = uploadedURL.absoluteString
                $0.uploadState = .ready
                $0.uploadProgress = 1
            }
            guard lifecycleID == operation else { return }
            if let ready = uploadedReferences.first(where: { $0.id == reference.id }) {
                await enqueue(reference: ready, intent: intent)
            }
        } catch {
            patchReference(reference.id) { $0.uploadState = .error; $0.uploadError = error.localizedDescription }
            guard lifecycleID == operation else { return }
            if selectionIntent == intent { errorMessage = error.localizedDescription }
        }
    }

    private func patchReference(_ id: String, update: (inout RealtimeReference) -> Void) {
        guard let index = uploadedReferences.firstIndex(where: { $0.id == id }) else { return }
        update(&uploadedReferences[index])
    }

    private func enqueue(reference: RealtimeReference, intent: UUID) async {
        let previous = application
        let operation = lifecycleID
        let task = Task { [weak self] in
            await previous?.value
            guard let self, self.lifecycleID == operation, self.selectionIntent == intent else { return }
            self.errorMessage = nil
            self.selectedReferenceID = reference.mode == .free && reference.referencePath.isEmpty ? nil : reference.id
            if reference.mode == .free { self.prompt = reference.prompt ?? self.prompt }
            do { try await self.generate(reference: reference) }
            catch {
                if self.lifecycleID == operation, self.selectionIntent == intent {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        application = task
        await task.value
    }

    private func generate(reference: RealtimeReference) async throws {
        guard let manager, let localStream else { return }
        let operation = lifecycleID
        let remote = try await manager.startGeneration(
            localStream: localStream,
            context: RealtimeContext(prompt: reference.prompt ?? reference.mode.prompt,
                                     referencePath: reference.referencePath.isEmpty ? nil : reference.referencePath),
            faceRestoration: reference.mode.faceRestoration
        )
        guard lifecycleID == operation else { return }
        remoteStream = remote
    }

    func removeFreeReference() {
        guard !isBusy, let reference = freeReference else { return }
        selectionIntent = UUID()
        if selectedReferenceID == reference.id { selectedReferenceID = nil }
        uploadedReferences.removeAll { $0.id == reference.id }
    }

    /// 同步 SDK 插帧开关及故障降级，不以逐帧状态驱动按钮。
    func refreshInterpolationState() async {
        let operation = lifecycleID
        guard let manager else { return }
        let enabled = await manager.isFrameInterpolationEnabled
        if lifecycleID == operation { interpolationEnabled = enabled }
    }

    func toggleInterpolation() async {
        guard sessionActive, !isBusy, let manager else { return }
        let operation = lifecycleID
        isBusy = true
        interpolationSwitching = true
        errorMessage = nil
        do { try await manager.setFrameInterpolationEnabled(!interpolationEnabled) }
        catch { if lifecycleID == operation { errorMessage = error.localizedDescription } }
        guard lifecycleID == operation else { return }
        await refreshInterpolationState()
        isBusy = false
        interpolationSwitching = false
    }

    func setRemoteAudioVolume(_ volume: Float) async {
        guard let manager else { return }
        let operation = lifecycleID
        do {
            try await manager.setRemoteAudioVolume(volume)
            if lifecycleID == operation { remoteAudioVolume = volume }
        } catch { if lifecycleID == operation { errorMessage = error.localizedDescription } }
    }

    func dismissError() { errorMessage = nil }

    /// 与 Web 一致，先返回启动页，再在后台完成 SDK 资源释放。
    func close() async {
        guard !isBusy else { return }
        let manager = manager
        resetSession()
        errorMessage = nil
        await manager?.close()
    }

    func viewDidDisappear() {
        let manager = manager
        resetSession()
        Task { await manager?.close() }
    }

    private func resetSession() {
        lifecycleID = UUID()
        selectionIntent = UUID()
        pendingInitialReference = nil
        application = nil
        manager = nil
        client = nil
        sessionActive = false
        isBusy = false
        interpolationSwitching = false
        localStream = nil
        remoteStream = nil
        state = RealtimeState(connectionState: .idle)
        sessionStartedAt = nil
        selectedReferenceID = nil
        uplinkStatistics = nil
        downlinkStatistics = nil
        networkQuality = nil
    }

    /// 与 Web 一致保留原始尺寸，以白底 JPEG 0.9 上传，避免透明图片变黑。
    nonisolated private static func jpegData(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw NSError(domain: "XLab", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Unable to decode reference image; please choose a supported image file"])
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let output = NSMutableData()
        guard let flattened = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, flattened, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return output as Data
    }
}
