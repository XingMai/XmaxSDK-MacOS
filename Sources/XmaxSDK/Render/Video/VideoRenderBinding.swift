//
//  VideoRenderBinding.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit

/// Binds a realtime video track to an AppKit render view.
@MainActor
final class VideoRenderBinding {

    /// Render operations
    private let attachHandler: (NSView, VideoContentMode) throws -> Void
    private let detachHandler: (NSView) throws -> Void

    /// Runtime state
    private weak var attachedView: NSView?

    /// Creates a track-to-view render binding.
    ///
    /// - Parameters:
    ///   - attachHandler: The operation binding content to a view and applying its display mode.
    ///   - detachHandler: The operation removing content from a view.
    init(
        attachHandler: @escaping (NSView, VideoContentMode) throws -> Void,
        detachHandler: @escaping (NSView) throws -> Void
    ) {
        self.attachHandler = attachHandler
        self.detachHandler = detachHandler
    }

    /// Unbinds the old view before binding content to the target view.
    ///
    /// - Parameters:
    ///   - view: The new render target view.
    ///   - contentMode: The video scaling and cropping mode.
    /// - Throws: An error if unbinding the old view or binding the new view fails.
    func attach(
        to view: NSView,
        contentMode: VideoContentMode
    ) throws {
        if let attachedView, attachedView !== view {
            try detachHandler(attachedView)
            self.attachedView = nil
        }

        try attachHandler(view, contentMode)
        attachedView = view
    }

    /// Unbinds rendering only if the specified view is currently bound.
    ///
    /// - Parameter view: The view to unbind.
    /// - Throws: An error if the underlying unbind operation fails.
    func detach(from view: NSView) throws {
        guard attachedView === view else {
            return
        }
        try detach()
    }

    /// Clears image preview and removes the current view render binding.
    ///
    /// - Throws: An error if the underlying unbind operation fails.
    func detach() throws {
        guard let attachedView else {
            return
        }
        try detachHandler(attachedView)
        self.attachedView = nil
    }
}
