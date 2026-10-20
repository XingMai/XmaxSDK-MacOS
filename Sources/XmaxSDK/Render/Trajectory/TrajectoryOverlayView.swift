//
//  TrajectoryOverlayView.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit

/// Collects primary-button drags; visual rendering and 30 Hz network sampling remain independent.
@MainActor
final class TrajectoryOverlayView: NSView {
    private weak var binding: TrajectoryBinding?
    private var enabled = false
    private var requested = true
    // A display flip cancels the current gesture, but never reverses its coordinates.
    private var mirrored = false
    private var contentMode: VideoContentMode = .fill
    private var displayedSize: CGSize?
    private var previousViewport: CGSize = .zero
    private var activePoint: TrajectoryPoint?
    private var sampler: Timer?
    private var renderer: any TrajectoryEffectRendering

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(renderer: any TrajectoryEffectRendering) {
        self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        installRenderer()
        NotificationCenter.default.addObserver(self, selector: #selector(cancelFromNotification),
            name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowResigned(_:)),
            name: NSWindow.didResignKeyNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    isolated deinit {
        sampler?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func setBinding(_ binding: TrajectoryBinding?, enabled: Bool) {
        cancelInteraction()
        self.binding = binding
        self.enabled = enabled
    }

    func configure(contentMode: VideoContentMode, mirrored: Bool, requested: Bool,
                   displayedSize: CGSize?) {
        guard self.contentMode != contentMode || self.mirrored != mirrored ||
                self.requested != requested || self.displayedSize != displayedSize else { return }
        cancelInteraction()
        self.contentMode = contentMode
        self.mirrored = mirrored
        self.requested = requested
        self.displayedSize = displayedSize
    }

    func setRenderer(_ renderer: any TrajectoryEffectRendering) {
        guard self.renderer !== renderer else { return }
        cancelInteraction()
        self.renderer.view.removeFromSuperview()
        self.renderer = renderer
        installRenderer()
    }

    override func layout() {
        super.layout()
        if previousViewport != bounds.size {
            cancelInteraction()
            previousViewport = bounds.size
        }
        renderer.view.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { cancelInteraction() }
    }

    override func viewDidHide() {
        super.viewDidHide()
        cancelInteraction()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard available, interactionFrame?.contains(local) == true else { return nil }
        // Custom effect views cannot intercept the SDK's pointer collection.
        return self
    }

    override func mouseDown(with event: NSEvent) {
        guard available, event.buttonNumber == 0,
              let point = makePoint(event, id: TrajectoryID(), clamp: false) else { return }
        window?.makeFirstResponder(self)
        cancelInteraction()
        activePoint = point
        renderer.renderBegan([point])
        sample()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        sampler = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func mouseDragged(with event: NSEvent) {
        guard available, let previous = activePoint,
              let point = makePoint(event, id: previous.id, clamp: true) else { return }
        activePoint = point
        renderer.renderMoved([point])
    }

    override func mouseUp(with event: NSEvent) {
        guard let previous = activePoint else { return }
        if let point = makePoint(event, id: previous.id, clamp: true) {
            activePoint = point
            renderer.renderMoved([point])
            sample()
        }
        renderer.renderEnded([previous.id])
        activePoint = nil
        stopSampling()
    }

    override func cancelOperation(_ sender: Any?) { cancelInteraction() }

    func cancelInteraction() {
        if let activePoint { renderer.renderEnded([activePoint.id]) }
        activePoint = nil
        stopSampling()
        renderer.reset()
    }

    private var available: Bool {
        enabled && requested && binding != nil && window != nil &&
            !isHiddenOrHasHiddenAncestor && interactionFrame != nil
    }

    private var displayedFrame: CGRect? {
        guard let displayedSize else { return nil }
        return InteractionCoordinateMapper.displayedFrame(viewportSize: bounds.size,
            videoSize: displayedSize, contentMode: contentMode)
    }

    private var interactionFrame: CGRect? {
        guard let frame = displayedFrame?.intersection(bounds), !frame.isEmpty, !frame.isNull else { return nil }
        return frame
    }

    private func makePoint(_ event: NSEvent, id: TrajectoryID, clamp: Bool) -> TrajectoryPoint? {
        guard let area = interactionFrame, let media = displayedFrame else { return nil }
        var location = convert(event.locationInWindow, from: nil)
        guard location.x.isFinite, location.y.isFinite else { return nil }
        if !clamp && !area.contains(location) { return nil }
        // Keep samples just inside max edges, which CGRect.contains otherwise excludes in fit mode.
        location.x = min(max(location.x, area.minX), area.maxX.nextDown)
        location.y = min(max(location.y, area.minY), area.maxY.nextDown)
        let x = (location.x - media.minX) / media.width
        return TrajectoryPoint(id: id, location: location,
            normalizedLocation: CGPoint(x: x,
                                        y: (location.y - media.minY) / media.height),
            timestamp: CACurrentMediaTime())
    }

    private func sample() {
        guard available, let point = activePoint else { cancelInteraction(); return }
        binding?.submit(InteractionFrame(points: [point.location], viewportSize: bounds.size,
            contentMode: contentMode, displayedVideoSize: displayedSize), from: self)
    }

    private func stopSampling() {
        sampler?.invalidate()
        sampler = nil
    }

    private func installRenderer() {
        renderer.view.frame = bounds
        renderer.view.autoresizingMask = [.width, .height]
        addSubview(renderer.view)
    }

    @objc private func cancelFromNotification() { cancelInteraction() }
    @objc private func windowResigned(_ notification: Notification) {
        if notification.object as? NSWindow === window { cancelInteraction() }
    }
}
