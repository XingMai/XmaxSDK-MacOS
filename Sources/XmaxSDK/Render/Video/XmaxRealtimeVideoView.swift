//
//  XmaxRealtimeVideoView.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit

/// 持续显示本地预览，并在远端首帧提交后覆盖显示生成结果。
@MainActor
public final class XmaxRealtimeVideoView: NSView {

    // 公共配置
    /// 本地摄像头视频轨道。
    public var localTrack: RealtimeVideoTrack? {
        didSet { localVideoView.track = localTrack }
    }

    /// 远端生成视频轨道；为空时立即恢复本地预览。
    public var remoteTrack: RealtimeVideoTrack? {
        didSet {
            guard oldValue !== remoteTrack else { return }
            updateRemoteTrack()
        }
    }

    /// 本地和远端视频共用的缩放与裁剪方式。
    public var videoContentMode: VideoContentMode = .fill {
        didSet {
            localVideoView.videoContentMode = videoContentMode
            remoteVideoView.videoContentMode = videoContentMode
        }
    }

    // 视频视图
    private let localVideoView = XmaxVideoView()
    private let remoteVideoView = XmaxVideoView()

    /// 创建实时视频容器。
    ///
    /// - Parameters:
    ///   - localTrack: 持续预览的本地轨道。
    ///   - remoteTrack: 覆盖显示的生成结果轨道。
    ///   - videoContentMode: 视频内容的显示模式。
    public init(
        localTrack: RealtimeVideoTrack? = nil,
        remoteTrack: RealtimeVideoTrack? = nil,
        videoContentMode: VideoContentMode = .fill
    ) {
        self.localTrack = localTrack
        self.remoteTrack = remoteTrack
        self.videoContentMode = videoContentMode
        super.init(frame: .zero)
        configureView()
    }

    /// 使用指定布局区域创建实时视频容器。
    ///
    /// - Parameter frame: 视图初始布局区域。
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    /// 从 Interface Builder 归档恢复实时视频容器。
    ///
    /// - Parameter coder: 视图归档解码器。
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    /// 同步两个视频子视图的布局。
    public override func layout() {
        super.layout()
        localVideoView.frame = bounds
        remoteVideoView.frame = bounds
    }

    /// 安装本地预览和远端结果图层。
    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        addSubview(localVideoView)
        addSubview(remoteVideoView)
        localVideoView.videoContentMode = videoContentMode
        remoteVideoView.videoContentMode = videoContentMode
        localVideoView.track = localTrack
        updateRemoteTrack()
    }

    /// 等待新远端轨道的首帧，防止切换期间显示空白画面。
    private func updateRemoteTrack() {
        remoteVideoView.frameDisplayHandler = nil
        remoteVideoView.track = nil
        remoteVideoView.isHidden = true
        guard let remoteTrack else { return }
        remoteVideoView.frameDisplayHandler = { [weak self, weak remoteTrack] in
            guard let self, self.remoteTrack === remoteTrack else { return }
            remoteVideoView.isHidden = false
            remoteVideoView.frameDisplayHandler = nil
        }
        remoteVideoView.track = remoteTrack
    }
}
