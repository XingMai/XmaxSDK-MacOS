//
//  TrajectoryBinding.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit

/// Connects one remote viewport to media interaction without owning task or transport state.
@MainActor
final class TrajectoryBinding {
    private let listener: RenderInteractionListener
    private weak var overlay: TrajectoryOverlayView?
    private var valid = true
    private var enabled = false
    private var revision = 0

    init(listener: @escaping RenderInteractionListener) {
        self.listener = listener
    }

    func attach(to overlay: TrajectoryOverlayView) {
        guard valid else { return }
        if self.overlay !== overlay {
            revision += 1
            self.overlay?.setBinding(nil, enabled: false)
            self.overlay = overlay
        }
        overlay.setBinding(self, enabled: enabled)
    }

    func detach(from overlay: TrajectoryOverlayView) {
        guard self.overlay === overlay else { return }
        revision += 1
        self.overlay = nil
        overlay.setBinding(nil, enabled: false)
    }

    /// A task or stream boundary cancels the old gesture even if interaction remains enabled.
    func update(enabled: Bool) {
        revision += 1
        self.enabled = enabled
        overlay?.setBinding(self, enabled: valid && enabled)
    }

    func submit(_ frame: InteractionFrame, from overlay: TrajectoryOverlayView) {
        guard valid, enabled, self.overlay === overlay else { return }
        let revision = revision
        Task { [weak self, weak overlay] in
            guard let self, let overlay, self.valid, self.enabled,
                  self.revision == revision, self.overlay === overlay else { return }
            await self.listener(frame)
        }
    }

    func invalidate() {
        valid = false
        update(enabled: false)
        overlay?.setBinding(nil, enabled: false)
        overlay = nil
    }
}
