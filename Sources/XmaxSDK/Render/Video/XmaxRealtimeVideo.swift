//
//  XmaxRealtimeVideo.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI

/// Automatically switches between local preview and remote generation in SwiftUI.
@MainActor
public struct XmaxRealtimeVideo: NSViewRepresentable {

    /// The displayed local video track.
    public let localTrack: RealtimeVideoTrack?

    /// The displayed remote generation video track.
    public let remoteTrack: RealtimeVideoTrack?

    /// The video content display mode in its container.
    public let videoContentMode: VideoContentMode

    /// Creates a SwiftUI realtime video component.
    ///
    /// - Parameters:
    ///   - localTrack: The local video track to preview continuously.
    ///   - remoteTrack: The remote generated track to display as an overlay.
    ///   - videoContentMode: The content display mode for local and remote video.
    public init(
        localTrack: RealtimeVideoTrack?,
        remoteTrack: RealtimeVideoTrack?,
        videoContentMode: VideoContentMode = .fill
    ) {
        self.localTrack = localTrack
        self.remoteTrack = remoteTrack
        self.videoContentMode = videoContentMode
    }

    /// Creates an AppKit view hosting SwiftUI video content.
    ///
    /// - Parameter context: The SwiftUI view creation context.
    /// - Returns: The SDK realtime video view configured with local and remote tracks.
    public func makeNSView(context: Context) -> XmaxRealtimeVideoView {
        XmaxRealtimeVideoView(
            localTrack: localTrack,
            remoteTrack: remoteTrack,
            videoContentMode: videoContentMode
        )
    }

    /// Synchronizes track and display configuration changes to the AppKit view.
    ///
    /// - Parameters:
    ///   - view: The SDK video view to update.
    ///   - context: The SwiftUI view update context.
    public func updateNSView(
        _ view: XmaxRealtimeVideoView,
        context: Context
    ) {
        view.videoContentMode = videoContentMode
        view.localTrack = localTrack
        view.remoteTrack = remoteTrack
    }

    /// Unbinds video tracks when SwiftUI removes the view.
    ///
    /// - Parameters:
    ///   - view: The SDK video view being removed.
    ///   - coordinator: The stateless SwiftUI coordinator.
    public static func dismantleNSView(
        _ view: XmaxRealtimeVideoView,
        coordinator: Void
    ) {
        view.localTrack = nil
        view.remoteTrack = nil
    }
}
