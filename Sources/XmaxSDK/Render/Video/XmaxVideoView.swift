//
//  XmaxVideoView.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
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

/// An AppKit container displaying local camera or remote generated video tracks.
@MainActor
public final class XmaxVideoView: NSView {

    /// The displayed video track; nil clears the binding.
    public var track: RealtimeVideoTrack? {
        didSet {
            guard oldValue !== track else { return }
            detach(track: oldValue)
            attachCurrentTrackIfNeeded()
        }
    }

    /// The video content display mode in its container.
    public var videoContentMode: VideoContentMode = .fill {
        didSet {
            guard oldValue != videoContentMode else { return }
            attachCurrentTrackIfNeeded()
        }
    }

    /// Render state
    private weak var attachedTrack: RealtimeVideoTrack?
    var frameDisplayHandler: (() -> Void)?

    /// Video preview
    private var decodedVideoLayer: AVSampleBufferDisplayLayer?
    private var decodedVideoTimebase: CMTimebase?
    private var nextDecodedVideoPresentationTime = CMTime.invalid

    /// Local preview buffer resources
    private var localPreviewPixelBufferPool: CVPixelBufferPool?
    private var localPreviewFormat: VideoFormat?
    private var localPreviewFormatDescription: CMVideoFormatDescription?

    /// Creates a video container with the specified track and display mode.
    ///
    /// - Parameters:
    ///   - track: The video track to display; may be assigned later.
    ///   - videoContentMode: The video content scaling and cropping mode.
    public init(track: RealtimeVideoTrack? = nil, videoContentMode: VideoContentMode = .fill) {
        self.track = track
        self.videoContentMode = videoContentMode
        super.init(frame: .zero)
        configureView()
    }

    /// Creates a video container with the specified frame.
    ///
    /// - Parameter frame: The initial view frame.
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    /// Restores a video container from an Interface Builder archive.
    ///
    /// - Parameter coder: The view archive decoder.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    /// Unbinds the track and releases preview resources when the view is destroyed.
    isolated deinit {
        detach(track: attachedTrack)
    }

    /// Synchronizes track binding with window attachment state.
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            detach(track: attachedTrack)
        } else {
            attachCurrentTrackIfNeeded()
        }
    }

    /// Updates layer layout without changing media format or realtime connection.
    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        decodedVideoLayer?.frame = bounds
        CATransaction.commit()
    }

    /// Uses top-down view coordinates.
    public override var isFlipped: Bool { true }

    /// Creates a layer container with a black background.
    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
    }
}

extension XmaxVideoView {
    /// Creates or updates the decoded video layer and its display clock.
    ///
    /// - Parameter contentMode: The video scaling and cropping mode.
    func prepareDecodedVideoPreview(contentMode: VideoContentMode) {
        let decodedVideoLayer: AVSampleBufferDisplayLayer
        if let currentLayer = self.decodedVideoLayer {
            decodedVideoLayer = currentLayer
        } else {
            decodedVideoLayer = AVSampleBufferDisplayLayer()
            // Updates video with rotation layout immediately, avoiding implicit sublayer scaling or flip animations.
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

    /// Sets horizontal mirroring for decoded video preview.
    ///
    /// - Parameter mirrored: Whether to mirror video horizontally.
    func setDecodedVideoPreviewMirrored(_ mirrored: Bool) {
        decodedVideoLayer?.setAffineTransform(CGAffineTransform(scaleX: mirrored ? -1 : 1, y: 1))
    }

    /// Converts local NV12 frames to samples and submits them for immediate preview.
    ///
    /// - Parameters:
    ///   - frame: The local video frame to display.
    ///   - contentMode: The video scaling and cropping mode.
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

    /// Submits remote frames with their durations and updates interaction mapping dimensions.
    ///
    /// - Parameters:
    ///   - frame: The remote video frame after interpolation and other processing.
    ///   - contentMode: The video scaling and cropping mode.
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

    /// Removes video layers and releases display clock and preview buffers.
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

    /// Logs rendering errors using the unified error description.
    ///
    /// - Parameters:
    ///   - title: The Chinese and English log titles.
    ///   - error: The rendering error to log.
    static func logRenderingFailure(
        title: String,
        error: any Error
    ) {
        XmaxLogger.render.error(
            message: "\(title)\n└─ \(XmaxLogger.localized("原因：", "Reason: "))" +
                (error as NSError).localizedDescription
        )
    }

    /// Binds the current track to preview after the view joins a window.
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

    /// Unbinds the current view's track while retaining capture and transport.
    ///
    /// - Parameter track: The track to unbind; nil does nothing.
    func detach(track: RealtimeVideoTrack?) {
        guard let track, attachedTrack === track else { return }
        do {
            try VideoRenderRegistry.binding(for: track)?.detach(from: self)
        } catch {
            Self.logRenderingFailure(title: "解除视频视图失败 (Failed to Detach Video View)", error: error)
        }
        attachedTrack = nil
    }

    /// Reuses a matching buffer pool to create a preview buffer.
    ///
    /// - Parameter frame: The local NV12 frame to copy.
    /// - Returns: The pixel buffer filled with current frame data.
    /// - Throws: An error on buffer pool creation or frame data copy failure.
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

    /// Reuses or creates a video format description matching the pixel buffer.
    ///
    /// - Parameter pixelBuffer: The current preview pixel buffer.
    /// - Returns: The description matching buffer dimensions and format.
    /// - Throws: An error if video format description creation fails.
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

    /// Validates and copies an NV12 frame into an IOSurface pixel buffer.
    ///
    /// - Parameters:
    ///   - frame: The NV12 frame to copy.
    ///   - pool: The reusable pixel buffer pool; `nil` allocates independently.
    /// - Returns: The pixel buffer containing luma and chroma planes.
    /// - Throws: An error on invalid frame layout or buffer allocation, locking, or copy failure.
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

    /// Copies the valid data of a pixel plane row by row.
    ///
    /// - Parameters:
    ///   - plane: The plane supplying source data and row stride.
    ///   - rowByteCount: The byte count to copy per row.
    ///   - rowCount: The number of rows to copy.
    ///   - destination: The destination plane base address.
    ///   - destinationStride: The destination plane byte count per row.
    /// - Throws: An error if source data or destination layout cannot accommodate the specified region.
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

    /// Frame validation errors
    static var invalidImageFrameError: XmaxError {
        XmaxError(code: .mediaError, message: "Video preview frame is invalid")
    }
}
