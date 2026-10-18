//
//  XmaxVideo.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI

/// Displays a local or remote realtime video track in SwiftUI.
@MainActor
public struct XmaxVideo: NSViewRepresentable {

    /// The displayed video track.
    public let track: RealtimeVideoTrack?

    /// The video content display mode in its container.
    public let videoContentMode: VideoContentMode

    /// Creates a SwiftUI video rendering component.
    ///
    /// - Parameters:
    ///   - track: The video track to display; nil shows an empty container.
    ///   - videoContentMode: The video content display mode.
    public init(
        track: RealtimeVideoTrack?,
        videoContentMode: VideoContentMode = .fill
    ) {
        self.track = track
        self.videoContentMode = videoContentMode
    }

    /// Creates an AppKit view hosting SwiftUI video content.
    ///
    /// - Parameter context: The SwiftUI view creation context.
    /// - Returns: The SDK video view configured for the current track.
    public func makeNSView(context: Context) -> XmaxVideoView {
        let view = XmaxVideoView(
            track: track,
            videoContentMode: videoContentMode
        )
        return view
    }

    /// Synchronizes track and display configuration changes to the AppKit view.
    ///
    /// - Parameters:
    ///   - view: The SDK video view to update.
    ///   - context: The SwiftUI view update context.
    public func updateNSView(
        _ view: XmaxVideoView,
        context: Context
    ) {
        view.videoContentMode = videoContentMode
        view.track = track
    }

    /// Unbinds video tracks when SwiftUI removes the view.
    ///
    /// - Parameters:
    ///   - view: The SDK video view being removed.
    ///   - coordinator: The stateless SwiftUI coordinator.
    public static func dismantleNSView(
        _ view: XmaxVideoView,
        coordinator: Void
    ) {
        view.track = nil
    }
}
