//
//  RealtimeViewController.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit
import Combine
import Kingfisher
import UniformTypeIdentifiers
import XmaxSDK

/// Owns persistent AppKit pages and applies coalesced session state updates to individual controls.
@MainActor
final class RealtimeViewController: NSViewController, NSTextFieldDelegate, NSTextViewDelegate {
    let controller = RealtimeSessionController()

    /// Window content and page containers
    private let root = RealtimeCanvas(color: .white)
    private let scroll = NSScrollView()
    private let document = RealtimeCanvas()
    private let header = RealtimeCanvas()
    private let landing = RealtimeCanvas()
    private let workspace = RealtimeCanvas()
    private let footer = RealtimeCanvas()
    private let logo = NSImageView()
    private let homeControls = RealtimeCanvas()
    private let sessionControls = RealtimeCanvas()
    private let titleLabel = realtimeLabel("Reimagining Live Video with Xmax", size: 32, weight: .medium)
    private let checkerboard = RealtimeCheckerboard()
    private let startButton = RealtimeButton("Start Camera", icon: .camera, style: .primary)
    private let microphonePill = RealtimeCanvas(color: .black.withAlphaComponent(0.2), radius: 16)
    private let microphoneLabel = realtimeLabel("Microphone", size: 13, color: NSColor(white: 0.65, alpha: 1))
    private let microphoneIcon = RealtimeButton(icon: .microphone, style: .plain)
    private let microphoneSwitch = NSSwitch()
    private let terms = NSTextView()
    private let copyright = realtimeLabel("Copyright © 2026 XMAX.AI PTE.LTD. All rights reserved.", size: 13, color: RealtimePalette.secondary)
    private let wechat = RealtimeButton(icon: .wechat, style: .plain)
    private let social = RealtimeButton(icon: .socialX, style: .plain)
    private let website = RealtimeButton(icon: .globe, style: .plain)
    private let contact = RealtimeButton("Contact Us", style: .plain)
    private let platform = RealtimeButton("API Platform", style: .plain)

    /// Header settings and session actions
    private let modelButton = RealtimeButton()
    private let keyButton = RealtimeButton(icon: .key)
    private let currentModel = RealtimeButton()
    private let statisticsButton = RealtimeButton(icon: .statistics, style: .statistics)
    private let volumeButton = RealtimeButton(icon: .muted)
    private let interpolationButton = RealtimeButton("2x", icon: .lightning, style: .interpolation)
    private let elapsed = RealtimeButton("00:00")
    private let stopButton = RealtimeButton("■  Stop Session", style: .destructive)
    private let keyField = NSTextField()
    private let volumeSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let volumeValue = realtimeLabel("Muted", size: 12, color: RealtimePalette.secondary)
    private var popover: NSPopover?
    private var volumeTask: Task<Void, Never>?
    private var pendingVolume: Float?

    /// Persistent video panels and mode-specific editors
    private lazy var localPanel = RealtimeVideoPanel(title: "Local", statistics: controller.localStatisticsPanels)
    private lazy var resultPanel = RealtimeVideoPanel(title: "Result", statistics: controller.remoteStatisticsPanels, showsWatermark: true)
    private let tabs = RealtimeCanvas(color: NSColor(srgbRed: 120 / 255, green: 120 / 255, blue: 128 / 255, alpha: 0.1), radius: 21)
    private var tabButtons: [RealtimeExampleMode: RealtimeButton] = [:]
    private var lists: [RealtimeExampleMode: RealtimeReferenceList] = [:]
    private let promptContainer = RealtimeCanvas(color: RealtimePalette.surface, radius: 18)
    private let promptScroll = NSScrollView()
    private let promptEditor = NSTextView()
    private let promptPlaceholder = realtimeLabel("Describe how you want the video to change", size: 15, color: RealtimePalette.secondary)
    private let freeReference = RealtimeReferenceButton()
    private let removeReference = RealtimeButton("×", style: .plain)
    private let submitButton = RealtimeButton(icon: .arrow, style: .primary)

    /// Error presentation and observation ownership
    private let toast = RealtimeCanvas(color: .white.withAlphaComponent(0.96), radius: 14)
    private let toastIcon = realtimeLabel("ⓘ", size: 18, color: .systemRed)
    private let toastMessage = realtimeLabel(size: 14)
    private let toastDismiss = RealtimeButton("×", style: .plain)
    private var observation: AnyCancellable?
    private var renderScheduled = false
    private var displayedSession: Bool?
    private var displayedMode: RealtimeExampleMode?
    private var displayedError: String?
    private var errorTask: Task<Void, Never>?
    private var ticker: Task<Void, Never>?

    override func loadView() {
        view = root
        root.frame = NSRect(x: 0, y: 0, width: 1360, height: 850)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.documentView = document
        root.addSubview(scroll)
        [header, landing, workspace, footer].forEach(document.addSubview)
        configureHeader()
        configureLanding()
        configureWorkspace()
        configureFooter()
        configureToast()
        observation = controller.objectWillChange.sink { [weak self] in
            // Published values notify before assignment; one main-queue turn reads the committed state.
            self?.scheduleRender()
        }
        render()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if ticker == nil {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    if let self, self.controller.sessionActive {
                        await self.controller.refreshInterpolationState()
                        self.updateElapsed()
                    }
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
        }
    }

    func shutdown() async {
        observation = nil
        ticker?.cancel(); ticker = nil
        errorTask?.cancel(); errorTask = nil
        pendingVolume = nil
        volumeTask?.cancel(); volumeTask = nil
        popover?.close()
        for list in lists.values { list.suspendImages() }
        await controller.shutdown()
    }

    private func scheduleRender() {
        guard !renderScheduled else { return }
        renderScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.renderScheduled = false
            self.render()
        }
    }

    private func configureHeader() {
        logo.image = NSImage(named: "XmaxWordmark")
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.setAccessibilityLabel("Xmax")
        [logo, homeControls, sessionControls].forEach(header.addSubview)
        [modelButton, keyButton].forEach(homeControls.addSubview)
        [currentModel, statisticsButton, volumeButton, interpolationButton, elapsed, stopButton].forEach(sessionControls.addSubview)
        modelButton.chevron = true
        modelButton.onClick = { [weak self] in self?.showModels() }
        keyButton.toolTip = "API Key"; keyButton.setAccessibilityLabel("API Key")
        keyButton.onClick = { [weak self] in self?.showKeyEditor() }
        currentModel.passive = true; currentModel.isEnabled = false
        elapsed.passive = true; elapsed.isEnabled = false
        statisticsButton.setAccessibilityLabel("Show statistics")
        statisticsButton.onClick = { [weak self] in self?.controller.statisticsVisible.toggle() }
        volumeButton.toolTip = "Adjust remote playback volume"
        volumeButton.setAccessibilityLabel("Remote volume")
        volumeButton.onClick = { [weak self] in self?.showVolume() }
        interpolationButton.setAccessibilityLabel("Frame interpolation")
        interpolationButton.onClick = { [weak self] in
            Task { [weak self] in await self?.controller.toggleInterpolation() }
        }
        stopButton.onClick = { [weak self] in Task { [weak self] in await self?.controller.close() } }
        keyField.delegate = self
        keyField.placeholderString = "API Key"
        keyField.font = RealtimeHeaderTypography.font(size: 13)
        keyField.bezelStyle = .roundedBezel
        keyField.setAccessibilityLabel("API Key")
        volumeSlider.target = self; volumeSlider.action = #selector(volumeChanged)
        volumeSlider.isContinuous = true
        volumeSlider.setAccessibilityLabel("Remote volume")
    }

    private func configureLanding() {
        [titleLabel, checkerboard, copyright].forEach(landing.addSubview)
        titleLabel.alignment = .center; copyright.alignment = .center
        [startButton, microphonePill, terms].forEach(checkerboard.addSubview)
        [microphoneIcon, microphoneLabel, microphoneSwitch].forEach(microphonePill.addSubview)
        microphonePill.layer?.borderWidth = 1
        microphonePill.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        microphoneIcon.passive = true
        microphoneSwitch.controlSize = .small
        microphoneSwitch.setAccessibilityLabel("Microphone")
        startButton.onClick = { [weak self] in
            guard let self else { return }
            let enabled = self.microphoneSwitch.state == .on
            Task { [weak self] in await self?.controller.start(useMicrophone: enabled) }
        }
        terms.isEditable = false; terms.isSelectable = true; terms.drawsBackground = false
        terms.textContainerInset = .zero
        terms.textContainer?.lineFragmentPadding = 0
        terms.linkTextAttributes = [.foregroundColor: NSColor(srgbRed: 0.765, green: 0.776, blue: 0.8, alpha: 1)]
    }

    private func configureWorkspace() {
        [localPanel, resultPanel, tabs, promptContainer].forEach(workspace.addSubview)
        for mode in RealtimeExampleMode.allCases {
            let button = RealtimeButton(mode.title, style: .tab)
            button.font = RealtimeHeaderTypography.font(size: 13.5, weight: .medium)
            button.onClick = { [weak self] in self?.controller.activeMode = mode }
            tabs.addSubview(button); tabButtons[mode] = button
            if mode != .free {
                let list = RealtimeReferenceList()
                list.onUpload = { [weak self] in self?.presentImporter(mode: mode) }
                list.onSelect = { [weak self] reference in
                    Task { [weak self] in await self?.controller.selectReference(reference) }
                }
                workspace.addSubview(list); lists[mode] = list
            }
        }
        promptContainer.layer?.borderWidth = 1
        promptContainer.layer?.borderColor = RealtimePalette.border.cgColor
        promptEditor.delegate = self
        promptEditor.font = RealtimeHeaderTypography.font(size: 15)
        promptEditor.textColor = RealtimePalette.text
        promptEditor.isRichText = false; promptEditor.drawsBackground = false
        promptEditor.isVerticallyResizable = true; promptEditor.isHorizontallyResizable = false
        promptEditor.autoresizingMask = [.width]
        promptEditor.textContainerInset = NSSize(width: 5, height: 6)
        promptEditor.textContainer?.widthTracksTextView = true
        promptEditor.setAccessibilityLabel("Describe how you want the video to change")
        promptScroll.drawsBackground = false; promptScroll.hasVerticalScroller = true
        promptScroll.documentView = promptEditor
        [promptScroll, promptPlaceholder, freeReference, removeReference, submitButton].forEach(promptContainer.addSubview)
        freeReference.compact = true
        freeReference.onClick = { [weak self] in
            guard let self else { return }
            if let reference = self.controller.freeReference, reference.uploadState == .error {
                Task { [weak self] in await self?.controller.selectReference(reference) }
            } else if self.controller.freeReference == nil { self.presentImporter(mode: .free) }
        }
        removeReference.toolTip = "Remove reference"
        removeReference.setAccessibilityLabel("Remove reference")
        removeReference.onClick = { [weak self] in self?.controller.removeFreeReference() }
        submitButton.setAccessibilityLabel("Submit prompt")
        submitButton.onClick = { [weak self] in Task { [weak self] in await self?.controller.submitPrompt() } }
    }

    private func configureFooter() {
        [wechat, social, website, contact, platform].forEach(footer.addSubview)
        wechat.setAccessibilityLabel("WeChat"); social.setAccessibilityLabel("X"); website.setAccessibilityLabel("Website")
        wechat.onClick = { [weak self] in self?.showWeChat() }
        social.onClick = { NSWorkspace.shared.open(URL(string: "https://x.com/XmaxAIOfficial")!) }
        website.onClick = { NSWorkspace.shared.open(URL(string: "https://www.xmaxai.com")!) }
        contact.onClick = { NSWorkspace.shared.open(URL(string: "mailto:contact@xmax.ai")!) }
        platform.onClick = { NSWorkspace.shared.open(URL(string: "https://platform.xmaxai.com")!) }
    }

    private func configureToast() {
        root.addSubview(toast)
        [toastIcon, toastMessage, toastDismiss].forEach(toast.addSubview)
        toast.layer?.borderWidth = 1; toast.layer?.borderColor = RealtimePalette.text.withAlphaComponent(0.08).cgColor
        toast.layer?.shadowColor = NSColor.black.cgColor; toast.layer?.shadowOpacity = 0.14
        toast.layer?.shadowRadius = 16; toast.layer?.shadowOffset = CGSize(width: 0, height: 8)
        toastMessage.maximumNumberOfLines = 0; toastMessage.lineBreakMode = .byWordWrapping
        toastMessage.isSelectable = true
        toastDismiss.setAccessibilityLabel("Dismiss")
        toastDismiss.onClick = { [weak self] in self?.controller.dismissError() }
    }

    /// Updates values without replacing controls, resetting list offsets, or restarting image requests.
    private func render() {
        let active = controller.sessionActive
        let pageChanged = displayedSession != active
        let keyTitle = controller.hasAPIKey ? controller.apiKey : ""
        let needsPageLayout = pageChanged || keyButton.title != keyTitle || displayedError != controller.errorMessage
        modelButton.title = controller.model.displayName
        modelButton.isEnabled = !controller.isBusy
        currentModel.title = controller.model.displayName
        keyButton.title = keyTitle
        startButton.title = controller.isBusy ? "Starting…" : "Start Camera"
        startButton.loading = controller.isBusy
        startButton.isEnabled = !controller.isBusy
        microphoneSwitch.isEnabled = !controller.isBusy
        statisticsButton.selected = controller.statisticsVisible
        statisticsButton.toolTip = controller.statisticsVisible ? "Hide statistics (collection and logging continue)" : "Show statistics"
        statisticsButton.setAccessibilityValue(controller.statisticsVisible ? "On" : "Off")
        volumeButton.icon = controller.remoteAudioVolume == 0 ? .muted : controller.remoteAudioVolume > 0.5 ? .volume : .volumeLow
        volumeButton.isEnabled = !controller.isClosing
        volumeButton.setAccessibilityValue(controller.remoteAudioVolume == 0 ? "Muted" : "\(Int(controller.remoteAudioVolume * 100))%")
        volumeSlider.isEnabled = !controller.isClosing
        if volumeTask == nil { volumeSlider.doubleValue = Double(controller.remoteAudioVolume) }
        volumeValue.stringValue = controller.remoteAudioVolume == 0 ? "Muted" : "\(Int(controller.remoteAudioVolume * 100))%"
        interpolationButton.selected = controller.interpolationEnabled
        interpolationButton.loading = controller.interpolationSwitching
        interpolationButton.isEnabled = !controller.isBusy
        interpolationButton.toolTip = controller.interpolationSwitching ? "Switching frame interpolation…" : controller.interpolationEnabled ? "2× frame interpolation is on. Click to turn off" : "Frame interpolation is off. Click to turn on"
        interpolationButton.setAccessibilityValue(controller.interpolationSwitching ? "Switching" : controller.interpolationEnabled ? "On" : "Off")
        stopButton.title = controller.isClosing ? "Stopping…" : "■  Stop Session"
        stopButton.loading = controller.isClosing
        stopButton.isEnabled = !controller.isClosing
        updateElapsed()

        // The preview is bound even while the landing page is visible, as required by SDK readiness.
        localPanel.update(track: controller.localStream?.videoTrack, message: "", statistics: controller.localStatisticsPanels, visible: controller.statisticsVisible)
        let placeholder = controller.state.connectionState == .generating && controller.remoteStream != nil ? "" :
            [.connected, .generating].contains(controller.state.connectionState) ? "Generating…" : "Waiting for connection…"
        resultPanel.update(track: controller.remoteStream?.videoTrack, message: placeholder, statistics: controller.remoteStatisticsPanels, visible: controller.statisticsVisible)
        resultPanel.mirrored = controller.localStream?.videoTrack?.position == .front
        for (mode, button) in tabButtons {
            button.selected = controller.activeMode == mode
            button.isEnabled = !controller.isBusy
            button.setAccessibilityValue(button.selected ? "Selected" : "")
        }
        for (mode, list) in lists {
            let visible = active && controller.activeMode == mode
            if !visible && !list.isHidden { list.suspendImages() }
            list.isHidden = !visible
            if visible {
                list.update(references: controller.uploadedReferences.filter { $0.mode == mode } + mode.presets,
                            selectedID: controller.selectedReferenceID, enabled: controller.canGenerate,
                            dimmed: !controller.canGenerate && !controller.interpolationSwitching)
            }
        }
        promptContainer.isHidden = controller.activeMode != .free
        promptEditor.isEditable = !controller.isClosing
        if promptEditor.string != controller.prompt { promptEditor.string = controller.prompt }
        promptPlaceholder.isHidden = !controller.prompt.isEmpty
        if active && controller.activeMode == .free {
            freeReference.configure(controller.freeReference, selected: false, enabled: controller.canGenerate)
        } else { freeReference.thumbnail.cancel() }
        removeReference.isHidden = controller.freeReference == nil
        removeReference.isEnabled = !controller.isBusy
        submitButton.isEnabled = controller.canGenerate && !controller.referenceUploading
        if displayedMode != controller.activeMode {
            // Resign the editor when switching modes so hidden text cannot receive keyboard input.
            if displayedMode == .free { view.window?.makeFirstResponder(nil) }
            displayedMode = controller.activeMode
        }
        homeControls.isHidden = active; sessionControls.isHidden = !active
        landing.isHidden = active; footer.isHidden = active
        workspace.isHidden = !active
        if pageChanged {
            displayedSession = active
            popover?.close()
            scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
            view.window?.makeFirstResponder(nil)
        }
        updateError()
        if needsPageLayout { view.needsLayout = true }
        if pageChanged {
            view.layoutSubtreeIfNeeded()
            animateEntry(active ? workspace : landing)
            if !active { animateEntry(footer) }
        }
    }

    private func updateElapsed() {
        let seconds = max(0, Int(Date().timeIntervalSince(controller.sessionStartedAt ?? Date())))
        let title = String(format: "%02d:%02d", seconds / 60, seconds % 60)
        if elapsed.title != title { elapsed.title = title }
    }

    private func animateEntry(_ page: NSView) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.45
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let move = CABasicAnimation(keyPath: "transform.translation.y")
        move.fromValue = 14; move.toValue = 0; move.duration = 0.45; move.timingFunction = fade.timingFunction
        page.layer?.add(fade, forKey: "pageEntryOpacity")
        page.layer?.add(move, forKey: "pageEntryPosition")
    }

    private func updateError() {
        toast.isHidden = controller.errorMessage == nil
        guard displayedError != controller.errorMessage else { return }
        displayedError = controller.errorMessage
        toastMessage.stringValue = controller.errorMessage ?? ""
        errorTask?.cancel()
        guard let message = controller.errorMessage else { return }
        NSAccessibility.post(element: toastMessage, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        errorTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.controller.dismissError()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        scroll.frame = root.bounds
        let width = scroll.contentSize.width
        let height = scroll.contentSize.height
        let contentWidth = max(0, width - 56)
        let panelWidth = (contentWidth - 24) / 2
        let panelHeight = panelWidth * 1024 / 1920
        let workspaceHeight = panelHeight + 34 + 42 + 28 + 190
        let stageWidth = min(contentWidth, min(940, max(580, width * 0.45)))
        let stageHeight = stageWidth * 1024 / 1920
        let titleSize = min(45, max(27, width * 0.01 + 18))
        let titleGap = min(40, max(26, width * 0.011 + 17))
        let landingHeight = titleSize + 12 + titleGap + stageHeight + 38
        let headerHeight: CGFloat = 84
        let active = controller.sessionActive
        let minimumHeight = active ? 16 + headerHeight + workspaceHeight + 48 : 16 + headerHeight + 30 + landingHeight + 30 + 82 + 48
        let documentHeight = max(height, minimumHeight)
        document.frame = NSRect(x: 0, y: 0, width: width, height: documentHeight)
        let surplus = max(0, documentHeight - minimumHeight)
        header.frame = NSRect(x: 28, y: 16 + (active ? surplus / 2 : 0), width: contentWidth, height: headerHeight)
        layoutHeader(viewportWidth: width)
        landing.frame = NSRect(x: 28, y: header.frame.maxY + 30 + surplus / 2, width: contentWidth, height: landingHeight)
        titleLabel.attributedStringValue = NSAttributedString(string: "Reimagining Live Video with Xmax", attributes: [
            .font: RealtimeHeaderTypography.font(size: titleSize, weight: .medium),
            .foregroundColor: RealtimePalette.text, .kern: -titleSize * 0.03,
            .paragraphStyle: { let style = NSMutableParagraphStyle(); style.alignment = .center; return style }()
        ])
        titleLabel.frame = NSRect(x: 0, y: 0, width: contentWidth, height: titleSize + 12)
        checkerboard.frame = NSRect(x: (contentWidth - stageWidth) / 2, y: titleSize + 12 + titleGap, width: stageWidth, height: stageHeight)
        layoutLanding(viewportWidth: width)
        copyright.frame = NSRect(x: 0, y: checkerboard.frame.maxY + 16, width: contentWidth, height: 20)
        workspace.frame = NSRect(x: 28, y: header.frame.maxY, width: contentWidth, height: workspaceHeight)
        localPanel.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        resultPanel.frame = NSRect(x: panelWidth + 24, y: 0, width: panelWidth, height: panelHeight)
        tabs.frame = NSRect(x: (contentWidth - 574) / 2, y: panelHeight + 34, width: 574, height: 42)
        var x: CGFloat = 4
        for mode in RealtimeExampleMode.allCases {
            let itemWidth: CGFloat = mode == .charx ? 155 : mode == .clothx ? 144 : mode == .vibex ? 137 : 124
            tabButtons[mode]?.frame = NSRect(x: x, y: 4, width: itemWidth, height: 34); x += itemWidth + 2
        }
        let listY = tabs.frame.maxY + 28
        for list in lists.values { list.frame = NSRect(x: 0, y: listY, width: contentWidth, height: 190) }
        let promptWidth = min(contentWidth, 880)
        promptContainer.frame = NSRect(x: (contentWidth - promptWidth) / 2, y: listY + 4, width: promptWidth, height: 160)
        promptScroll.frame = NSRect(x: 20, y: 12, width: promptWidth - 40, height: 84)
        promptEditor.setFrameSize(NSSize(width: promptScroll.contentSize.width, height: max(84, promptEditor.frame.height)))
        promptPlaceholder.frame = NSRect(x: 29, y: 18, width: promptWidth - 58, height: 22)
        freeReference.frame = NSRect(x: promptWidth - 110, y: 104, width: 44, height: 44)
        removeReference.frame = NSRect(x: promptWidth - 79, y: 96, width: 22, height: 22)
        submitButton.frame = NSRect(x: promptWidth - 56, y: 104, width: 44, height: 44)
        footer.frame = NSRect(x: 28, y: documentHeight - 74, width: contentWidth, height: 26)
        wechat.frame = NSRect(x: 0, y: 0, width: 24, height: 24)
        social.frame = NSRect(x: 42, y: 0, width: 24, height: 24)
        website.frame = NSRect(x: 84, y: 0, width: 24, height: 24)
        contact.frame = NSRect(x: contentWidth - 210, y: 0, width: 98, height: 26)
        platform.frame = NSRect(x: contentWidth - 100, y: 0, width: 100, height: 26)
        layoutToast()
    }

    private func layoutHeader(viewportWidth width: CGFloat) {
        let logoHeight = min(52, max(34, width * 0.008 + 24))
        let controlHeight = min(48, max(35, width * 0.0055 + 26))
        logo.frame = NSRect(x: 0, y: 8, width: logoHeight * 552 / 172, height: logoHeight)
        let keyWidth = controller.hasAPIKey ? min(310, max(60, (controller.apiKey as NSString).size(withAttributes: [.font: keyButton.font!]).width + 52)) : controlHeight
        let homeWidth = 190 + 12 + keyWidth
        homeControls.frame = NSRect(x: header.bounds.width - homeWidth, y: 8, width: homeWidth, height: controlHeight)
        modelButton.frame = NSRect(x: 0, y: 0, width: 190, height: controlHeight)
        keyButton.frame = NSRect(x: 202, y: 0, width: keyWidth, height: controlHeight)
        sessionControls.frame = NSRect(x: header.bounds.width - 702, y: 8, width: 702, height: 36)
        let controls: [(RealtimeButton, CGFloat)] = [(currentModel, 180), (statisticsButton, 36), (volumeButton, 36), (interpolationButton, 66), (elapsed, 74), (stopButton, 150)]
        var x: CGFloat = 0
        for (button, size) in controls { button.frame = NSRect(x: x, y: 0, width: size, height: 36); x += size + 12 }
    }

    private func layoutLanding(viewportWidth width: CGFloat) {
        let fontSize = min(18, max(15, width * 0.003 + 12))
        let smallSize = min(15, max(12, width * 0.0028 + 9.5))
        let buttonHeight = fontSize + 6 + min(16, max(12, width * 0.0028 + 9)) * 2
        let buttonWidth = min(270, max(220, width * 0.04 + 180))
        let groupHeight = buttonHeight + 12 + 32
        startButton.frame = NSRect(x: (checkerboard.bounds.width - buttonWidth) / 2, y: (checkerboard.bounds.height - groupHeight) / 2, width: buttonWidth, height: buttonHeight)
        startButton.font = RealtimeHeaderTypography.font(size: fontSize, weight: .semibold)
        microphonePill.frame = NSRect(x: checkerboard.bounds.midX - 84, y: startButton.frame.maxY + 12, width: 168, height: 32)
        microphoneIcon.frame = NSRect(x: 9, y: 5, width: 19, height: 22)
        microphoneLabel.font = RealtimeHeaderTypography.font(size: smallSize)
        microphoneLabel.frame = NSRect(x: 32, y: 7, width: 87, height: 20)
        microphoneSwitch.frame = NSRect(x: 126, y: 4, width: 36, height: 24)
        terms.frame = NSRect(x: 20, y: checkerboard.bounds.height - 55, width: checkerboard.bounds.width - 40, height: 40)
        let text = "By clicking Start, you agree to our Terms of Use and Privacy Policy."
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: RealtimeHeaderTypography.font(size: smallSize), .paragraphStyle: paragraph,
            .foregroundColor: NSColor(srgbRed: 0.612, green: 0.639, blue: 0.686, alpha: 1)
        ])
        attributed.addAttribute(.link, value: "https://platform.xmaxai.com/docs/resources/terms", range: (text as NSString).range(of: "Terms of Use"))
        attributed.addAttribute(.link, value: "https://platform.xmaxai.com/docs/resources/privacy", range: (text as NSString).range(of: "Privacy Policy"))
        if !terms.attributedString().isEqual(to: attributed) { terms.textStorage?.setAttributedString(attributed) }
    }

    private func layoutToast() {
        let width = min(590, max(0, root.bounds.width - 56))
        let textWidth = max(1, width - 90)
        let textHeight = (toastMessage.stringValue as NSString).boundingRect(with: NSSize(width: textWidth, height: 500), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: toastMessage.font!]).height
        let height = max(52, ceil(textHeight) + 24)
        toast.frame = NSRect(x: (root.bounds.width - width) / 2, y: 84, width: width, height: height)
        toastIcon.frame = NSRect(x: 16, y: (height - 24) / 2, width: 24, height: 24)
        toastMessage.frame = NSRect(x: 48, y: 12, width: textWidth, height: height - 24)
        toastDismiss.frame = NSRect(x: width - 38, y: (height - 26) / 2, width: 24, height: 26)
    }

    /// Popovers use native fields and controls, keeping keyboard editing independent of session redraws.
    private func presentPopover(content: NSView, from button: NSView) {
        popover?.close()
        let controller = NSViewController(); controller.view = content
        let popover = NSPopover(); popover.behavior = .transient
        popover.contentViewController = controller; popover.contentSize = content.frame.size
        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    private func showModels() {
        let content = RealtimeCanvas(); content.frame.size = NSSize(width: 256, height: CGFloat(RealtimeModel.allCases.count) * 36 + 16)
        for (index, model) in RealtimeModel.allCases.enumerated() {
            let option = RealtimeButton(model.displayName + (controller.model == model ? "  ✓" : ""), style: .tab)
            option.selected = controller.model == model
            option.frame = NSRect(x: 8, y: CGFloat(index) * 36 + 8, width: 240, height: 34)
            option.onClick = { [weak self] in
                guard let self, !self.controller.isBusy else { return }
                self.controller.model = model; self.popover?.close()
            }
            content.addSubview(option)
        }
        presentPopover(content: content, from: modelButton)
    }

    private func showKeyEditor() {
        let content = RealtimeCanvas(); content.frame.size = NSSize(width: 280, height: 56)
        keyField.stringValue = controller.apiKey
        keyField.frame = NSRect(x: 10, y: 10, width: 260, height: 36)
        content.addSubview(keyField)
        presentPopover(content: content, from: keyButton)
        keyField.window?.makeFirstResponder(keyField)
    }

    private func showVolume() {
        let content = RealtimeCanvas(); content.frame.size = NSSize(width: 244, height: 88)
        let label = realtimeLabel("Remote volume", size: 12)
        label.frame = NSRect(x: 14, y: 14, width: 145, height: 18)
        volumeValue.frame = NSRect(x: 159, y: 14, width: 71, height: 18); volumeValue.alignment = .right
        volumeSlider.frame = NSRect(x: 14, y: 46, width: 216, height: 24)
        [label, volumeValue, volumeSlider].forEach(content.addSubview)
        presentPopover(content: content, from: volumeButton)
    }

    @objc private func volumeChanged() {
        let value = Float(volumeSlider.doubleValue)
        volumeValue.stringValue = value == 0 ? "Muted" : "\(Int(value * 100))%"
        pendingVolume = value
        guard volumeTask == nil else { return }
        volumeTask = Task { [weak self] in
            guard let self else { return }
            while let value = self.pendingVolume, !Task.isCancelled {
                self.pendingVolume = nil
                await self.controller.setRemoteAudioVolume(value)
            }
            self.volumeTask = nil
            self.scheduleRender()
        }
    }

    private func showWeChat() {
        let content = RealtimeCanvas(); content.frame.size = NSSize(width: 208, height: 242)
        let image = NSImageView(frame: NSRect(x: 14, y: 14, width: 180, height: 180))
        image.imageScaling = .scaleProportionallyUpOrDown
        image.kf.setImage(with: URL(string: "https://assets.22duck.fun/image/wechatAccount.jpg"), options: [
            .processor(DownsamplingImageProcessor(size: NSSize(width: 180, height: 180))),
            .scaleFactor(view.window?.backingScaleFactor ?? 2), .backgroundDecode
        ])
        let label = realtimeLabel("Follow us on WeChat", size: 12)
        label.alignment = .center; label.frame = NSRect(x: 14, y: 202, width: 180, height: 24)
        content.addSubview(image); content.addSubview(label)
        presentPopover(content: content, from: wechat)
    }

    private func presentImporter(mode: RealtimeExampleMode) {
        guard controller.canGenerate, let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor [weak self] in await self?.controller.uploadReference(at: url, mode: mode) }
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        if notification.object as? NSTextField === keyField { controller.apiKey = keyField.stringValue }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            popover?.close(); return true
        }
        return false
    }
    func textDidChange(_ notification: Notification) {
        if notification.object as? NSTextView === promptEditor { controller.prompt = promptEditor.string }
    }
}
