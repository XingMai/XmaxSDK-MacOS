//
//  XmaxVideoView.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-macOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

@preconcurrency import AVFoundation
import AppKit
import CoreMedia
import CoreVideo

/// 显示本地摄像头或远端生成视频轨道的 AppKit 容器。
@MainActor
public final class XmaxVideoView: NSView {

    // 公共配置
    /// 当前显示的视频轨道；为空时清除绑定。
    public var track: RealtimeVideoTrack? {
        didSet {
            guard oldValue !== track else { return }
            detach(track: oldValue)
            attachCurrentTrackIfNeeded()
        }
    }

    /// 视频内容在容器中的显示模式。
    public var videoContentMode: VideoContentMode = .fill {
        didSet {
            guard oldValue != videoContentMode else { return }
            attachCurrentTrackIfNeeded()
        }
    }

    // 渲染状态
    private weak var attachedTrack: RealtimeVideoTrack?
    var frameDisplayHandler: (() -> Void)?

    // 视频预览
    private var decodedVideoLayer: AVSampleBufferDisplayLayer?
    private var decodedVideoTimebase: CMTimebase?
    private var nextDecodedVideoPresentationTime = CMTime.invalid

    // 本地预览缓冲资源
    private var localPreviewPixelBufferPool: CVPixelBufferPool?
    private var localPreviewFormat: VideoFormat?
    private var localPreviewFormatDescription: CMVideoFormatDescription?

    /// 创建指定轨道和显示模式的视频容器。
    ///
    /// - Parameters:
    ///   - track: 需要显示的视频轨道；可以稍后设置。
    ///   - videoContentMode: 视频内容的缩放与裁剪方式。
    public init(track: RealtimeVideoTrack? = nil, videoContentMode: VideoContentMode = .fill) {
        self.track = track
        self.videoContentMode = videoContentMode
        super.init(frame: .zero)
        configureView()
    }

    /// 使用指定布局区域创建视频容器。
    ///
    /// - Parameter frame: 视图初始布局区域。
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    /// 从 Interface Builder 归档恢复视频容器。
    ///
    /// - Parameter coder: 视图归档解码器。
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    /// 销毁视图时解除轨道绑定及预览资源。
    isolated deinit {
        detach(track: attachedTrack)
    }

    /// 随窗口挂载状态同步轨道绑定。
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            detach(track: attachedTrack)
        } else {
            attachCurrentTrackIfNeeded()
        }
    }

    /// 仅更新图层布局，不改变媒体规格或实时连接。
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        decodedVideoLayer?.frame = bounds
        CATransaction.commit()
    }

    /// 使用由上向下的视图坐标。
    public override var isFlipped: Bool { true }

    /// 创建黑色背景的图层容器。
    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
    }
}

extension XmaxVideoView {
    /// 创建或更新解码视频图层及其显示时钟。
    ///
    /// - Parameter contentMode: 视频画面的缩放与裁剪方式。
    func prepareDecodedVideoPreview(contentMode: VideoContentMode) {
        let decodedVideoLayer: AVSampleBufferDisplayLayer
        if let currentLayer = self.decodedVideoLayer {
            decodedVideoLayer = currentLayer
        } else {
            decodedVideoLayer = AVSampleBufferDisplayLayer()
            // 视频内容跟随旋转布局立即更新，不叠加子图层的隐式缩放和翻转动画。
            decodedVideoLayer.actions = [
                "bounds": NSNull(),
                "position": NSNull(),
                "transform": NSNull(),
                "videoGravity": NSNull()
            ]
            decodedVideoLayer.frame = bounds
            layer?.insertSublayer(decodedVideoLayer, at: 0)
            self.decodedVideoLayer = decodedVideoLayer

            var timebase: CMTimebase?
            let status = CMTimebaseCreateWithSourceClock(
                allocator: kCFAllocatorDefault,
                sourceClock: CMClockGetHostTimeClock(),
                timebaseOut: &timebase
            )
            if status == noErr, let timebase {
                CMTimebaseSetTime(timebase, time: .zero)
                CMTimebaseSetRate(timebase, rate: 1)
                decodedVideoLayer.controlTimebase = timebase
                decodedVideoTimebase = timebase
            }
        }
        decodedVideoLayer.videoGravity = contentMode == .fit ?
            .resizeAspect : .resizeAspectFill
    }

    /// 设置解码视频预览的水平镜像。
    ///
    /// - Parameter mirrored: 是否水平镜像画面。
    func setDecodedVideoPreviewMirrored(_ mirrored: Bool) {
        decodedVideoLayer?.setAffineTransform(CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1))
    }

    /// 将本地 NV12 帧转换为样本并立即提交预览。
    ///
    /// - Parameters:
    ///   - frame: 待显示的本地视频帧。
    ///   - contentMode: 视频画面的缩放与裁剪方式。
    func displayDecodedVideoFrame(
        _ frame: VideoFrame,
        contentMode: VideoContentMode
    ) {
        if decodedVideoLayer == nil {
            prepareDecodedVideoPreview(contentMode: contentMode)
        }
        guard let decodedVideoLayer,
              let decodedVideoTimebase else {
            return
        }
        decodedVideoLayer.videoGravity = contentMode == .fit ?
            .resizeAspect : .resizeAspectFill
        if decodedVideoLayer.requiresFlushToResumeDecoding {
            decodedVideoLayer.flush()
        }

        do {
            let pixelBuffer = try makeLocalPreviewPixelBuffer(frame)
            let formatDescription = try localPreviewDescription(for: pixelBuffer)
            let presentationTime = CMTimebaseGetTime(decodedVideoTimebase)
            var timing = CMSampleTimingInfo(
                duration: .invalid,
                presentationTimeStamp: presentationTime,
                decodeTimeStamp: .invalid
            )
            var sampleBuffer: CMSampleBuffer?
            guard CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescription: formatDescription,
                sampleTiming: &timing,
                sampleBufferOut: &sampleBuffer
            ) == noErr,
                  let sampleBuffer else {
                throw Self.invalidImageFrameError
            }
            CMSetAttachment(
                sampleBuffer,
                key: kCMSampleAttachmentKey_DisplayImmediately,
                value: kCFBooleanTrue,
                attachmentMode: kCMAttachmentMode_ShouldPropagate
            )
            decodedVideoLayer.enqueue(sampleBuffer)
            frameDisplayHandler?()
        } catch {
            Self.logRenderingFailure(
                title: "显示本地视频帧失败 (Failed to Display Local Video Frame)",
                error: error
            )
        }
    }

    /// 按帧时长提交远端画面，并同步交互映射尺寸。
    ///
    /// - Parameters:
    ///   - frame: 已完成插帧等处理的远端视频帧。
    ///   - contentMode: 视频画面的缩放与裁剪方式。
    func displayRemoteVideoFrame(
        _ frame: RealtimeVideoFrame,
        contentMode: VideoContentMode
    ) {
        if decodedVideoLayer == nil {
            prepareDecodedVideoPreview(contentMode: contentMode)
        }
        guard let decodedVideoLayer,
              let decodedVideoTimebase else {
            return
        }
        decodedVideoLayer.videoGravity = contentMode == .fit ?
            .resizeAspect : .resizeAspectFill
        if decodedVideoLayer.requiresFlushToResumeDecoding {
            decodedVideoLayer.flush()
            nextDecodedVideoPresentationTime = .invalid
        }

        var formatDescription: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescriptionOut: &formatDescription
        ) == noErr,
              let formatDescription else {
            return
        }

        let currentTime = CMTimebaseGetTime(decodedVideoTimebase)
        let presentationTime: CMTime
        if nextDecodedVideoPresentationTime.isValid,
           nextDecodedVideoPresentationTime >= currentTime {
            presentationTime = nextDecodedVideoPresentationTime
        } else {
            presentationTime = currentTime
        }
        let duration = frame.duration.isValid && frame.duration > .zero ?
            frame.duration : CMTime(value: 1, timescale: 24)
        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        ) == noErr,
              let sampleBuffer else {
            return
        }
        decodedVideoLayer.enqueue(sampleBuffer)
        nextDecodedVideoPresentationTime = presentationTime + duration
        frameDisplayHandler?()
    }

    /// 移除视频图层并释放显示时钟和预览缓冲资源。
    func clearDecodedVideoPreview() {
        decodedVideoLayer?.flushAndRemoveImage()
        decodedVideoLayer?.controlTimebase = nil
        decodedVideoLayer?.removeFromSuperlayer()
        decodedVideoLayer = nil
        decodedVideoTimebase = nil
        nextDecodedVideoPresentationTime = .invalid
        localPreviewPixelBufferPool = nil
        localPreviewFormat = nil
        localPreviewFormatDescription = nil
    }

    /// 输出带统一错误描述的渲染日志。
    ///
    /// - Parameters:
    ///   - title: 中英文日志标题。
    ///   - error: 需要记录的渲染错误。
    static func logRenderingFailure(
        title: String,
        error: any Error
    ) {
        XmaxLogger.render.error(
            message: "\(title)\n└─ \(XmaxLogger.localized("原因：", "Reason: "))" +
                (error as NSError).localizedDescription
        )
    }

    /// 在视图挂载窗口后，将当前轨道绑定到预览视图。
    func attachCurrentTrackIfNeeded() {
        guard window != nil, let track,
              let binding = VideoRenderRegistry.binding(for: track) else { return }
        do {
            try binding.attach(to: self, contentMode: videoContentMode)
            attachedTrack = track
        } catch {
            attachedTrack = nil
            Self.logRenderingFailure(title: "绑定视频视图失败 (Failed to Attach Video View)", error: error)
        }
    }

    /// 解除当前视图持有的轨道，保留媒体采集与传输。
    ///
    /// - Parameter track: 待解除的轨道；为空时忽略。
    func detach(track: RealtimeVideoTrack?) {
        guard let track, attachedTrack === track else { return }
        do {
            try VideoRenderRegistry.binding(for: track)?.detach(from: self)
        } catch {
            Self.logRenderingFailure(title: "解除视频视图失败 (Failed to Detach Video View)", error: error)
        }
        attachedTrack = nil
    }

    /// 复用符合当前帧规格的缓冲池创建预览缓冲区。
    ///
    /// - Parameter frame: 待复制的本地 NV12 视频帧。
    /// - Returns: 已填充当前帧数据的像素缓冲区。
    /// - Throws: 缓冲池创建或帧数据复制失败时抛出错误。
    func makeLocalPreviewPixelBuffer(_ frame: VideoFrame) throws -> CVPixelBuffer {
        if localPreviewFormat != frame.format || localPreviewPixelBufferPool == nil {
            let attributes: [String: Any] = [
                kCVPixelBufferWidthKey as String: frame.format.width,
                kCVPixelBufferHeightKey as String: frame.format.height,
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary
            ]
            var pool: CVPixelBufferPool?
            guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess,
                  let pool else {
                throw Self.invalidImageFrameError
            }
            localPreviewPixelBufferPool = pool
            localPreviewFormat = frame.format
            localPreviewFormatDescription = nil
        }

        return try Self.makeNV12PixelBuffer(frame, pool: localPreviewPixelBufferPool)
    }

    /// 复用或创建与像素缓冲区匹配的视频格式描述。
    ///
    /// - Parameter pixelBuffer: 当前预览像素缓冲区。
    /// - Returns: 与缓冲区尺寸和格式匹配的描述。
    /// - Throws: 视频格式描述创建失败时抛出错误。
    func localPreviewDescription(for pixelBuffer: CVPixelBuffer) throws -> CMVideoFormatDescription {
        if let description = localPreviewFormatDescription,
           CMVideoFormatDescriptionMatchesImageBuffer(description, imageBuffer: pixelBuffer) {
            return description
        }

        var description: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &description
        ) == noErr, let description else {
            throw Self.invalidImageFrameError
        }
        localPreviewFormatDescription = description
        return description
    }

    /// 校验并复制 NV12 帧到 IOSurface 像素缓冲区。
    ///
    /// - Parameters:
    ///   - frame: 待复制的 NV12 视频帧。
    ///   - pool: 可复用的像素缓冲池；`nil` 时单独分配。
    /// - Returns: 包含亮度及色度平面的像素缓冲区。
    /// - Throws: 帧布局无效、缓冲区分配、锁定或复制失败时抛出错误。
    static func makeNV12PixelBuffer(
        _ frame: VideoFrame,
        pool: CVPixelBufferPool? = nil
    ) throws -> CVPixelBuffer {
        let width = frame.format.width
        let height = frame.format.height
        guard frame.format.pixelFormat == .nv12,
              width > 0,
              height > 0,
              width.isMultiple(of: 2),
              height.isMultiple(of: 2),
              frame.planes.count == 2 else {
            throw invalidImageFrameError
        }

        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ] as CFDictionary
        let status: CVReturn
        if let pool {
            status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                attributes,
                &pixelBuffer
            )
        }
        guard status == kCVReturnSuccess, let pixelBuffer,
              CVPixelBufferGetWidth(pixelBuffer) == width,
              CVPixelBufferGetHeight(pixelBuffer) == height,
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange else {
            throw invalidImageFrameError
        }

        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) ==
                kCVReturnSuccess else {
            throw invalidImageFrameError
        }
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        }

        try copyPlane(
            frame.planes[0],
            rowByteCount: width,
            rowCount: height,
            destination: CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
            destinationStride: CVPixelBufferGetBytesPerRowOfPlane(
                pixelBuffer,
                0
            )
        )
        try copyPlane(
            frame.planes[1],
            rowByteCount: width,
            rowCount: height / 2,
            destination: CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
            destinationStride: CVPixelBufferGetBytesPerRowOfPlane(
                pixelBuffer,
                1
            )
        )
        return pixelBuffer
    }

    /// 按行复制一个像素平面的有效数据。
    ///
    /// - Parameters:
    ///   - plane: 提供源数据和行步长的平面。
    ///   - rowByteCount: 每行需要复制的字节数。
    ///   - rowCount: 需要复制的行数。
    ///   - destination: 目标平面起始地址。
    ///   - destinationStride: 目标平面每行字节数。
    /// - Throws: 源数据或目标布局不能容纳指定区域时抛出错误。
    static func copyPlane(
        _ plane: VideoFramePlane,
        rowByteCount: Int,
        rowCount: Int,
        destination: UnsafeMutableRawPointer?,
        destinationStride: Int
    ) throws {
        let (sourceLength, sourceLengthOverflow) = plane.stride
            .multipliedReportingOverflow(by: rowCount)
        guard let destination,
              rowByteCount > 0,
              rowCount > 0,
              plane.stride >= rowByteCount,
              destinationStride >= rowByteCount,
              !sourceLengthOverflow,
              plane.byteLength >= sourceLength,
              plane.byteOffset <= plane.data.count - sourceLength else {
            throw invalidImageFrameError
        }

        plane.data.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress else { return }
            let sourceStart = source.advanced(by: plane.byteOffset)
            if plane.stride == rowByteCount, destinationStride == rowByteCount {
                memcpy(destination, sourceStart, sourceLength)
                return
            }
            for row in 0..<rowCount {
                memcpy(
                    destination.advanced(by: row * destinationStride),
                    sourceStart.advanced(by: row * plane.stride),
                    rowByteCount
                )
            }
        }
    }

    // 帧校验错误
    static var invalidImageFrameError: XmaxError {
        XmaxError(code: .mediaError, message: "Video preview frame is invalid")
    }
}
