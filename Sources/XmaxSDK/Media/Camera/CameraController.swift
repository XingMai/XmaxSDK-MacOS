//
//  CameraController.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-macOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import CoreGraphics
import Foundation

/// 协调系统摄像头采集、外部视频上传和 SDK 本地预览。
final class CameraController: CameraControlling, @unchecked Sendable {

    // 轨道标识
    private static let localVideoTrackID = "video0"

    // 基础层组件
    private let rtcManager: any RtcManaging
    private let permissionManager: any PermissionManaging
    private let captureManager: any CameraCaptureManaging

    // 服务层组件
    private let mediaService: any MediaServicing

    // 事件监听
    private let videoFrameListener: MediaVideoFrameListener
    private let errorListener: XmaxErrorListener
    private var previewReadyHandler: CameraPreviewReadyHandler?

    // 并发控制
    private let stateLock = NSLock()

    // 本地资源
    private var activeTrack: RealtimeVideoTrack?
    private var preview: Preview?

    // 预览状态
    private var hasCapturedFrame = false
    private var isPreviewAttached = false

    // 麦克风配置与采集状态
    private var storedUseMicrophone = false
    private var isMicrophoneCapturing = false

    /// 使用系统权限和采集组件创建摄像头控制器。
    ///
    /// - Parameters:
    ///   - rtcManager: 配置 RTC 外部视频和麦克风的组件。
    ///   - mediaService: 提供模型尺寸规则的服务。
    ///   - videoFrameListener: 接收相机视频帧的回调。
    ///   - errorListener: 接收采集运行错误的回调。
    @MainActor
    convenience init(
        rtcManager: any RtcManaging,
        mediaService: any MediaServicing = MediaService(),
        videoFrameListener: @escaping MediaVideoFrameListener,
        errorListener: @escaping XmaxErrorListener
    ) {
        self.init(
            rtcManager: rtcManager,
            permissionManager: PermissionManager(),
            mediaService: mediaService,
            captureManager: CameraCaptureManager(),
            videoFrameListener: videoFrameListener,
            errorListener: errorListener
        )
    }

    /// 使用指定依赖创建摄像头控制器。
    ///
    /// - Parameters:
    ///   - rtcManager: RTC 媒体适配组件。
    ///   - permissionManager: 摄像头及麦克风权限组件。
    ///   - mediaService: 模型尺寸规则服务。
    ///   - captureManager: 系统视频采集组件。
    ///   - videoFrameListener: 接收相机视频帧的回调。
    ///   - errorListener: 接收采集运行错误的回调。
    init(
        rtcManager: any RtcManaging,
        permissionManager: any PermissionManaging,
        mediaService: any MediaServicing,
        captureManager: any CameraCaptureManaging,
        videoFrameListener: @escaping MediaVideoFrameListener = { _ in },
        errorListener: @escaping XmaxErrorListener = { _ in }
    ) {
        self.rtcManager = rtcManager
        self.permissionManager = permissionManager
        self.mediaService = mediaService
        self.captureManager = captureManager
        self.videoFrameListener = videoFrameListener
        self.errorListener = errorListener
    }

    /// 查询可用于创建或切换摄像头流的设备。
    ///
    /// - Returns: 当前可用的摄像头设备。
    func listCameraDevices() -> [CameraDevice] {
        captureManager.listCameraDevices()
    }

    /// 解析显式设备标识或系统默认设备，不自动替换已失效的显式选择。
    ///
    /// - Parameter deviceID: 指定设备标识；为空时使用默认设备。
    /// - Returns: 当前可用的目标设备。
    /// - Throws: 指定设备不可用或没有摄像头时抛出媒体错误。
    private func resolveDevice(_ deviceID: String?) throws -> CameraDevice {
        let devices = captureManager.listCameraDevices()
        let device: CameraDevice?
        if let deviceID {
            device = devices.first { $0.id == deviceID }
        } else {
            device = devices.first { $0.isDefault } ?? devices.first
        }
        guard let device else {
            throw XmaxError(code: .mediaError, message: "The requested camera is unavailable")
        }
        return device
    }

    // 本地媒体状态
    /// 当前活动的本地相机视频轨道；尚未创建时返回空值。
    var currentTrack: RealtimeVideoTrack? {
        stateLock.withLock { activeTrack }
    }

    /// 当前相机流是否配置为使用麦克风。
    var useMicrophone: Bool {
        stateLock.withLock { activeTrack != nil && storedUseMicrophone }
    }

    /// 设置当前相机流的一次性内部就绪处理；条件为已收到有效帧且预览已绑定。
    ///
    /// - Parameter handler: 就绪时调用的处理闭包；传入空值时清除。
    func setPreviewReadyHandler(_ handler: CameraPreviewReadyHandler?) {
        let track = stateLock.withLock {
            previewReadyHandler = handler
            return activeTrack
        }
        if let track { notifyPreviewReady(for: track) }
    }

    /// 创建并启动本地相机流。
    ///
    /// - Parameters:
    ///   - videoFormat: 期望的输出尺寸、帧率和编码配置；尺寸按模型规则调整。
    ///   - deviceID: 首次启动使用的设备标识；为空时使用系统默认摄像头。
    ///   - useMicrophone: 是否申请麦克风权限并允许实时连接时启动音频采集。
    /// - Returns: 包含本地相机视频轨道的媒体流。
    /// - Throws: 已有活动相机流、格式无效、权限不足或采集启动失败时抛出错误。
    func createLocalCameraStream(
        videoFormat: RealtimeVideoFormat,
        deviceID: String?,
        useMicrophone: Bool = false
    ) async throws -> RealtimeMediaStream {
        guard currentTrack == nil else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Stop the current local camera stream before creating another one"
            )
        }
        let resolvedFormat = try resolveVideoFormat(videoFormat)
        try await permissionManager.ensureCameraPermission()
        let device = try resolveDevice(deviceID)
        let track = RealtimeVideoTrack(
            id: Self.localVideoTrackID,
            videoFormat: resolvedFormat,
            position: device.position,
            device: device
        )
        do {
            if useMicrophone {
                try await permissionManager.ensureMicrophonePermission()
            }
            try Task.checkCancellation()
            try rtcManager.useExternalVideoSource()
            try rtcManager.configureLocalVideoMirror(for: .unspecified)
            let preview = await makePreview(for: track, position: device.position)
            stateLock.withLock {
                activeTrack = track
                self.preview = preview
                storedUseMicrophone = useMicrophone
                hasCapturedFrame = false
                isPreviewAttached = false
            }
            try await captureManager.start(
                videoFormat: VideoFormat(
                    width: resolvedFormat.width,
                    height: resolvedFormat.height,
                    pixelFormat: .nv12
                ),
                frameRate: resolvedFormat.fps,
                deviceID: device.id,
                frameListener: { [weak self] frame in
                    try self?.handleFrame(frame, track: track, preview: preview)
                },
                errorListener: { [weak self] error in
                    guard let self, currentTrack === track else { return }
                    errorListener(error)
                }
            )
            try Task.checkCancellation()
            return RealtimeMediaStream(id: StreamID.local.rawValue, videoTrack: track)
        } catch {
            await stopLocalCameraStream()
            throw XmaxError.from(error)
        }
    }

    /// 为已启用麦克风的相机流启动音频采集，不开启本地回放。
    ///
    /// - Throws: RTC 音频源配置或麦克风采集启动失败时抛出错误。
    func startMicrophoneCapture() throws {
        try stateLock.withLock {
            guard activeTrack != nil, storedUseMicrophone, !isMicrophoneCapturing else { return }
            // 启动失败时也保留待停止状态，由连接清理回收可能已启动的设备。
            isMicrophoneCapturing = true
            try rtcManager.startAudioCapture()
        }
    }

    /// 停止麦克风采集，保留下一次连接所需的配置。
    ///
    /// - Throws: RTC 麦克风采集停止失败时抛出错误。
    func stopMicrophoneCapture() throws {
        try stateLock.withLock {
            guard isMicrophoneCapturing else { return }
            try rtcManager.stopAudioCapture()
            isMicrophoneCapturing = false
        }
    }

    /// 停止相机和麦克风采集，并释放当前轨道及本地预览资源。
    func stopLocalCameraStream() async {
        do {
            try stopMicrophoneCapture()
        } catch {
            XmaxLogger.realtime.error(
                message: """
                停止麦克风采集失败 (Failed to Stop Microphone Capture)
                └─ \(XmaxLogger.localized("原因：", "Reason: "))\((error as NSError).localizedDescription)
                """
            )
        }
        let resources = stateLock.withLock {
            let resources = (activeTrack, preview)
            activeTrack = nil
            preview = nil
            previewReadyHandler = nil
            storedUseMicrophone = false
            isMicrophoneCapturing = false
            hasCapturedFrame = false
            isPreviewAttached = false
            return resources
        }
        await captureManager.stop()
        resources.1?.dispatcher.reset()
        await MainActor.run {
            if let track = resources.0 { VideoRenderRegistry.unregister(track) }
            resources.1?.presenter.clear()
        }
    }

    /// 切换到指定摄像头设备，保留当前视频轨道。
    ///
    /// - Returns: 包含更新后相机轨道的媒体流。
    /// - Throws: 相机流尚未启动、设备切换或镜像配置失败时抛出错误。
    func switchCamera(to deviceID: String) async throws -> RealtimeMediaStream {
        guard let track = currentTrack, let previousDevice = track.device else {
            throw XmaxError(code: .rtcError, message: "Local camera preview is not started")
        }
        let device = try resolveDevice(deviceID)
        try await captureManager.switchCamera(to: device.id)
        do {
            try rtcManager.configureLocalVideoMirror(for: .unspecified)
        } catch {
            try? await captureManager.switchCamera(to: previousDevice.id)
            throw error
        }
        track.updateDevice(device)
        let preview = stateLock.withLock { self.preview }
        await preview?.presenter.setMirrored(device.position == .front)
        return RealtimeMediaStream(id: StreamID.local.rawValue, videoTrack: track)
    }

}

private extension CameraController {
    /// 持有摄像头预览呈现器和帧分发器。
    struct Preview: Sendable {

        // 预览组件
        let presenter: DecodedVideoPreviewPresenter
        let dispatcher: DecodedVideoPreviewDispatcher
    }

    /// 创建并注册相机轨道对应的预览绑定。
    ///
    /// - Parameters:
    ///   - track: 需要预览的本地相机轨道。
    ///   - position: 决定预览镜像的摄像头位置。
    /// - Returns: 供后续帧提交和资源释放使用的预览组件。
    @MainActor
    func makePreview(for track: RealtimeVideoTrack, position: CameraPosition) -> Preview {
        let presenter = DecodedVideoPreviewPresenter()
        presenter.setMirrored(position == .front)
        let preview = Preview(
            presenter: presenter,
            dispatcher: DecodedVideoPreviewDispatcher(presenter: presenter)
        )
        VideoRenderRegistry.register(track, binding: VideoRenderBinding(
            attachHandler: { [weak self] view, contentMode in
                guard let videoView = view as? XmaxVideoView else {
                    throw XmaxError(
                        code: .invalidConfiguration,
                        message: "Camera tracks require an XmaxVideoView"
                    )
                }
                presenter.attach(to: videoView, contentMode: contentMode)
                self?.stateLock.withLock { self?.isPreviewAttached = true }
                self?.notifyPreviewReady(for: track)
            },
            detachHandler: { [weak self] view in
                if let videoView = view as? XmaxVideoView { presenter.detach(from: videoView) }
                self?.stateLock.withLock { self?.isPreviewAttached = false }
            }
        ))
        return preview
    }

    /// 将当前轨道的采集帧提交给预览和媒体监听器。
    ///
    /// - Parameters:
    ///   - frame: 已完成方向和尺寸转换的采集帧。
    ///   - track: 产生该帧的相机轨道。
    ///   - preview: 该轨道持有的预览组件。
    /// - Throws: 视频帧监听器处理失败时抛出错误。
    func handleFrame(_ frame: VideoFrame, track: RealtimeVideoTrack, preview: Preview) throws {
        let accepted = try stateLock.withLock {
            guard activeTrack === track else { return false }
            preview.dispatcher.enqueue(frame)
            hasCapturedFrame = true
            try videoFrameListener(frame)
            return true
        }
        if accepted { notifyPreviewReady(for: track) }
    }

    /// 在已有有效帧和预览绑定时一次性通知就绪。
    ///
    /// - Parameter track: 需要核对有效性的相机轨道。
    func notifyPreviewReady(for track: RealtimeVideoTrack) {
        let shouldNotify = stateLock.withLock {
            activeTrack === track && hasCapturedFrame && isPreviewAttached &&
                previewReadyHandler != nil
        }
        guard shouldNotify else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let handler = stateLock.withLock { () -> CameraPreviewReadyHandler? in
                guard activeTrack === track, hasCapturedFrame, isPreviewAttached else {
                    return nil
                }
                let handler = previewReadyHandler
                previewReadyHandler = nil
                return handler
            }
            handler? { [weak self] in
                guard let self else { return false }
                return stateLock.withLock {
                    activeTrack === track
                }
            }
        }
    }

    /// 按模型尺寸规则解析摄像头的实际输出规格。
    ///
    /// - Parameter videoFormat: 调用方请求的相机视频规格。
    /// - Returns: 保留帧率及编码选项的有效输出规格。
    /// - Throws: 输入规格无效或模型不支持目标尺寸时抛出错误。
    func resolveVideoFormat(_ videoFormat: RealtimeVideoFormat) throws -> RealtimeVideoFormat {
        try videoFormat.validate()
        let targetSize = try mediaService.resolveMediaSize(
            CGSize(width: videoFormat.width, height: videoFormat.height),
            source: .camera
        )
        let resolvedFormat = videoFormat.resized(width: Int(targetSize.width), height: Int(targetSize.height))
        try resolvedFormat.validate()
        return resolvedFormat
    }
}
