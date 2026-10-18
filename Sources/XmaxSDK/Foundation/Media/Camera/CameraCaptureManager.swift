//
//  CameraCaptureManager.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

@preconcurrency import AVFoundation
import Foundation

/// 使用 AVFoundation 采集视频；设备操作和帧处理由同一串行队列管理。
final class CameraCaptureManager: NSObject, CameraCaptureManaging, @unchecked Sendable {

    /// 平台资源
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "ai.xmax.sdk.camera", qos: .userInitiated)

    /// 采集配置（仅在 captureQueue 访问）
    private var input: AVCaptureDeviceInput?
    private var videoFormat: VideoFormat?
    private var frameRate = 0

    /// 事件监听
    private var frameListener: (@Sendable (VideoFrame) throws -> Void)?
    private var errorListener: XmaxErrorListener?
    private var observers: [NSObjectProtocol] = []

    /// 运行状态
    private var lastTimestampUs: Int64?
    private var hasReportedFrameError = false

    /// 查询内置、外接及系统提供的连续互通摄像头。
    ///
    /// - Returns: 当前可选择的设备及默认设备状态。
    func listCameraDevices() -> [CameraDevice] {
        let defaultID = AVCaptureDevice.default(for: .video)?.uniqueID
        return Self.captureDevices().map { device in
            CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultID,
                position: Self.resolvePosition(device.position, deviceType: device.deviceType)
            )
        }
    }

    /// 将系统摄像头位置转换为 SDK 位置；macOS 内置摄像头未报告位置时按前置处理。
    ///
    /// - Parameters:
    ///   - position: 系统报告的摄像头位置。
    ///   - deviceType: 用于识别内置摄像头的设备类型。
    /// - Returns: 预览和上传镜像共同使用的摄像头位置。
    static func resolvePosition(
        _ position: AVCaptureDevice.Position,
        deviceType: AVCaptureDevice.DeviceType
    ) -> CameraPosition {
        if position == .front { return .front }
        if position == .back { return .back }
        return deviceType == .builtInWideAngleCamera ? .front : .unspecified
    }

    /// 查询系统视频设备，不启动采集会话。
    ///
    /// - Returns: 当前系统提供的视频采集设备。
    private static func captureDevices() -> [AVCaptureDevice] {
        let types: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            types = [.builtInWideAngleCamera, .external, .continuityCamera]
        } else {
            types = [.builtInWideAngleCamera, .externalUnknown]
        }
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: .unspecified
        ).devices
    }

    /// 启动摄像头，输出已经转正并调整到目标尺寸的 NV12 帧。
    ///
    /// - Parameters:
    ///   - videoFormat: 输出像素格式和尺寸。
    ///   - frameRate: 采集帧率。
    ///   - deviceID: 目标摄像头设备标识。
    ///   - frameListener: 在采集串行队列接收视频帧。
    ///   - errorListener: 接收采集运行错误。
    /// - Throws: 设备、规格或采集启动失败时抛出错误。
    func start(
        videoFormat: VideoFormat,
        frameRate: Int,
        deviceID: String,
        frameListener: @escaping @Sendable (VideoFrame) throws -> Void,
        errorListener: @escaping XmaxErrorListener
    ) async throws {
        try Task.checkCancellation()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            captureQueue.async { [self] in
                do {
                    guard self.videoFormat == nil else {
                        throw Self.cameraError("Camera capture is already running")
                    }
                    guard frameRate > 0, frameRate <= Int(Int32.max),
                          videoFormat.pixelFormat == .nv12,
                          videoFormat.width.isMultiple(of: 2), videoFormat.height.isMultiple(of: 2) else {
                        throw Self.cameraError("Camera capture format is invalid")
                    }

                    self.videoFormat = videoFormat
                    self.frameRate = frameRate
                    self.frameListener = frameListener
                    self.errorListener = errorListener

                    session.beginConfiguration()

                    do {
                        session.sessionPreset = .high
                        try replaceInput(deviceID: deviceID)

                        guard session.canAddOutput(output) else {
                            throw Self.cameraError("Camera video output is unavailable")
                        }
                        session.addOutput(output)

                        guard output.availableVideoPixelFormatTypes.contains(
                            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                        ) else {
                            throw Self.cameraError("Camera does not support NV12 video output")
                        }
                        output.videoSettings = [
                            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                        ]
                        output.alwaysDiscardsLateVideoFrames = true
                        output.setSampleBufferDelegate(self, queue: captureQueue)
                        try configureConnection()
                    } catch {
                        session.commitConfiguration()
                        throw error
                    }
                    session.commitConfiguration()

                    observeSession()
                    session.startRunning()
                    guard session.isRunning else {
                        throw Self.cameraError("Camera capture failed to start")
                    }

                    continuation.resume()
                } catch {
                    stopCapture()
                    continuation.resume(
                        throwing: error as? XmaxError ?? Self.cameraError(error.localizedDescription)
                    )
                }
            }
        }
    }

    /// 切换摄像头，保持输出尺寸和帧率。
    ///
    /// - Parameter position: 目标摄像头位置。
    /// - Throws: 设备不可用或切换失败时抛出错误。
    func switchCamera(to deviceID: String) async throws {
        try Task.checkCancellation()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            captureQueue.async { [self] in
                do {
                    guard videoFormat != nil else {
                        throw Self.cameraError("Camera capture is not running")
                    }

                    session.beginConfiguration()
                    defer {
                        session.commitConfiguration()
                    }

                    let previousInput = input
                    do {
                        try replaceInput(deviceID: deviceID)
                        try configureConnection()
                    } catch {
                        if let input {
                            session.removeInput(input)
                        }
                        input = nil

                        if let previousInput, session.canAddInput(previousInput) {
                            session.addInput(previousInput)
                            input = previousInput
                            try? configureConnection()
                        }

                        throw error
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(
                        throwing: error as? XmaxError ?? Self.cameraError(error.localizedDescription)
                    )
                }
            }
        }
    }

    /// 停止采集，等待正在处理的帧结束并释放设备。
    func stop() async {
        await withCheckedContinuation { continuation in
            captureQueue.async { [self] in
                stopCapture()
                continuation.resume()
            }
        }
    }

}

extension CameraCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// 将采集帧转换为目标尺寸和方向，并回调使用主机时钟时间戳的视频帧。
    ///
    /// - Parameters:
    ///   - output: 输出视频样本的采集输出。
    ///   - sampleBuffer: 包含像素缓冲区和采集时间戳的视频样本。
    ///   - connection: 当前视频输出的采集连接。
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let videoFormat, let frameListener,
              connection === self.output.connection(with: .video),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let captureClock = session.synchronizationClock

        guard let clock = captureClock else {
            return
        }

        let hostTime = CMSyncConvertTime(
            CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            from: clock,
            to: CMClockGetHostTimeClock()
        )
        guard hostTime.isNumeric else {
            return
        }

        let timestampUs = CMTimeConvertScale(
            hostTime,
            timescale: 1000000,
            method: .default
        ).value
        guard timestampUs >= 0, lastTimestampUs.map({ timestampUs > $0 }) ?? true else {
            return
        }
        lastTimestampUs = timestampUs

        do {
            let frame = try NV12VideoFrameConverter.convert(
                pixelBuffer: pixelBuffer,
                outputWidth: videoFormat.width,
                outputHeight: videoFormat.height,
                rotation: .rotation0,
                timestampUs: timestampUs
            )
            try frameListener(frame)
        } catch {
            guard !hasReportedFrameError else {
                return
            }

            hasReportedFrameError = true
            XmaxLogger.media.error(message: "摄像头帧处理失败 (Camera Frame Processing Failed)\n└─ \(XmaxLogger.localized("原因：", "Reason: "))\(error.localizedDescription)")
        }
    }
}

private extension CameraCaptureManager {
    /// 替换摄像头输入，并应用支持目标帧率的采集格式。
    ///
    /// - Parameter position: 目标摄像头位置。
    /// - Throws: 摄像头不可用、采集格式不受支持或设备配置失败时抛出错误。
    func replaceInput(deviceID: String) throws {
        guard let device = Self.captureDevices().first(where: { $0.uniqueID == deviceID }) else {
            throw Self.cameraError("The requested camera is unavailable")
        }

        // 优先选择不超过 1920×1080 的 16:9 格式，再回退到不超过 1920×1440 的 4:3 格式。
        let selected = device.formats.compactMap { format -> (
            format: AVCaptureDevice.Format, area: Int64, isWide: Bool
        )? in
            guard format.videoSupportedFrameRateRanges.contains(where: {
                $0.minFrameRate <= Double(frameRate) && Double(frameRate) <= $0.maxFrameRate
            }) else {
                return nil
            }

            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let longSide = Int64(max(dimensions.width, dimensions.height))
            let shortSide = Int64(min(dimensions.width, dimensions.height))
            let isWide = longSide * 9 == shortSide * 16
            guard longSide > 0, shortSide > 0,
                  longSide <= 1920, shortSide <= 1440,
                  isWide || longSide * 3 == shortSide * 4 else {
                return nil
            }

            return (format, longSide * shortSide, isWide)
        }.max { lhs, rhs in
            if lhs.isWide != rhs.isWide {
                return !lhs.isWide
            }

            return lhs.area < rhs.area
        }?.format

        guard let selected else {
            throw Self.cameraError(
                "The camera does not support a compatible 16:9 or 4:3 format at the requested frame rate"
            )
        }

        let newInput = try AVCaptureDeviceInput(device: device)
        if let input {
            session.removeInput(input)
        }
        input = nil

        guard session.canAddInput(newInput) else {
            throw Self.cameraError("Failed to attach the requested camera")
        }
        session.addInput(newInput)
        input = newInput

        try device.lockForConfiguration()
        defer {
            device.unlockForConfiguration()
        }

        device.activeFormat = selected
        let duration = CMTime(value: 1, timescale: Int32(frameRate))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }

    /// 配置视频采集连接，并关闭系统自动镜像。
    ///
    /// - Throws: 采集连接不可用或不支持方向设置时抛出错误。
    func configureConnection() throws {
        guard let connection = output.connection(with: .video) else {
            throw Self.cameraError("Camera video connection is unavailable")
        }
        // 原生 macOS 以设备输出为基准，窗口布局不改变采集方向。
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    /// 监听设备断开与采集异常，并在采集中断结束后尝试恢复。
    func observeSession() {
        let errorListener = errorListener
        observers.append(NotificationCenter.default.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil
        ) { [weak self] notification in
            let deviceID = (notification.object as? AVCaptureDevice)?.uniqueID
            self?.captureQueue.async { [weak self] in
                guard let self, videoFormat != nil, input?.device.uniqueID == deviceID else { return }
                errorListener?(Self.cameraError("The active camera was disconnected"))
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
            let message = error?.localizedDescription ?? "Camera capture failed"

            self?.captureQueue.async { [weak self] in
                guard let self, videoFormat != nil else {
                    return
                }

                errorListener?(Self.cameraError(message))
            }
        })

        observers.append(NotificationCenter.default.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { [weak self] _ in
            self?.captureQueue.async { [weak self] in
                guard let self, videoFormat != nil, !session.isRunning else {
                    return
                }

                session.startRunning()
                if !session.isRunning {
                    errorListener?(Self.cameraError("Camera capture failed to resume"))
                }
            }
        })
    }

    /// 停止采集并移除输入、输出、观察者及帧回调。
    func stopCapture() {
        frameListener = nil
        errorListener = nil
        videoFormat = nil

        output.setSampleBufferDelegate(nil, queue: nil)
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        session.stopRunning()
        session.beginConfiguration()
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        session.commitConfiguration()

        input = nil
        frameRate = 0
        lastTimestampUs = nil
        hasReportedFrameError = false
    }

    /// 构造摄像头采集错误。
    ///
    /// - Parameter message: 错误描述。
    /// - Returns: 包含指定描述的媒体错误。
    static func cameraError(_ message: String) -> XmaxError {
        XmaxError(code: .mediaError, message: message)
    }
}
