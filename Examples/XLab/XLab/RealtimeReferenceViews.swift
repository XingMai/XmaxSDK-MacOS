//
//  RealtimeReferenceViews.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit
import Kingfisher

/// Crops cached thumbnails to fill their circle without stretching the source image.
final class RealtimeThumbnail: NSImageView {
    private var sourceID: String?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ reference: RealtimeReference?) {
        guard sourceID != reference?.id else { return }
        kf.cancelDownloadTask()
        sourceID = reference?.id
        image = nil
        guard let reference else { return }
        let source: Source
        var options: KingfisherOptionsInfo = [.backgroundDecode, .scaleFactor(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2)]
        if let data = reference.thumbnailData {
            source = .provider(RawImageDataProvider(data: data, cacheKey: reference.id))
            options += [.cacheMemoryOnly, .processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80)))]
        } else if reference.thumbnailURL.isFileURL {
            source = .provider(LocalFileImageDataProvider(fileURL: reference.thumbnailURL))
            options.append(.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))))
        } else {
            source = .network(KF.ImageResource(downloadURL: reference.thumbnailURL))
        }
        // Remote URLs already request COS thumbnails; downloading the full image is unnecessary.
        kf.setImage(with: source, options: options)
    }

    func cancel() {
        kf.cancelDownloadTask()
        if image == nil { sourceID = nil }
    }

    override func layout() { super.layout(); layer?.cornerRadius = min(bounds.width, bounds.height) / 2 }

    override func draw(_ dirtyRect: NSRect) {
        RealtimePalette.surface.setFill(); bounds.fill()
        guard let image, image.size.width > 0, image.size.height > 0 else {
            let symbol = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            symbol?.draw(in: NSRect(x: bounds.midX - 8, y: bounds.midY - 8, width: 16, height: 16),
                         from: .zero, operation: .sourceOver, fraction: 0.3, respectFlipped: true, hints: nil)
            return
        }
        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height)
        let crop = NSRect(x: (image.size.width - bounds.width / scale) / 2,
                          y: (image.size.height - bounds.height / scale) / 2,
                          width: bounds.width / scale, height: bounds.height / scale)
        image.draw(in: bounds, from: crop, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
}

/// Reusable native reference buttons update selection and upload progress in place.
final class RealtimeReferenceButton: NSButton {
    let thumbnail = RealtimeThumbnail()
    private let spinner = RealtimeSpinner()
    private var reference: RealtimeReference?
    private var selected = false
    private var configured = false
    private var hovered = false
    private var hoverArea: NSTrackingArea?
    var onClick: (() -> Void)?
    var compact = false
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.momentaryPushIn)
        target = self; action = #selector(invoke)
        addSubview(thumbnail)
        addSubview(overlay)
        overlay.addSubview(progressLabel)
        addSubview(spinner)
        spinner.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func invoke() { onClick?() }

    func configure(_ reference: RealtimeReference?, selected: Bool, enabled: Bool) {
        thumbnail.configure(reference)
        let canSelect = enabled && reference?.uploadState != .uploading
        guard !configured || self.reference?.id != reference?.id || self.selected != selected ||
                self.reference?.uploadState != reference?.uploadState ||
                self.reference?.uploadProgress != reference?.uploadProgress ||
                self.reference?.uploadError != reference?.uploadError || isEnabled != canSelect else { return }
        configured = true
        self.reference = reference; self.selected = selected
        isEnabled = canSelect
        thumbnail.isHidden = reference == nil
        spinner.setSpinning(reference?.uploadState == .uploading, color: .white)
        toolTip = reference?.uploadError.map { $0 + " — Click to retry" } ?? reference?.name ?? "Upload your own reference image"
        setAccessibilityLabel(reference?.name ?? "Upload reference image")
        setAccessibilityValue(selected ? "Selected" : "")
        needsDisplay = true; needsLayout = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area); hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }

    override func layout() {
        super.layout()
        let size: CGFloat = compact ? 44 : 64
        thumbnail.frame = NSRect(x: (bounds.width - size) / 2, y: 0, width: size, height: size)
        spinner.frame = NSRect(x: bounds.midX - 8, y: size / 2 - 14, width: 16, height: 16)
    }

    override func draw(_ dirtyRect: NSRect) {
        let size: CGFloat = compact ? 44 : 64
        let circle = NSRect(x: (bounds.width - size) / 2 + 1, y: 1, width: size - 2, height: size - 2)
        let outline = NSBezierPath(ovalIn: circle)
        if reference == nil {
            RealtimePalette.surface.setFill(); outline.fill()
            outline.setLineDash([4, 3], count: 2, phase: 0)
            RealtimePalette.border.setStroke(); outline.lineWidth = 2; outline.stroke()
            RealtimeWebIcon.draw(.plus, in: NSRect(x: bounds.midX - 12, y: size / 2 - 12, width: 24, height: 24), color: RealtimePalette.secondary)
        }
        if !compact {
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
            let attributes: [NSAttributedString.Key: Any] = [
                .font: RealtimeHeaderTypography.font(size: 11, weight: selected ? .semibold : .regular),
                .foregroundColor: selected ? RealtimePalette.accent : RealtimePalette.secondary, .paragraphStyle: paragraph
            ]
            ((reference?.name ?? "Upload") as NSString).draw(in: NSRect(x: 0, y: 70, width: bounds.width, height: 14), withAttributes: attributes)
        }
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        thumbnail.layer?.borderWidth = 2
        thumbnail.layer?.borderColor = (selected ? RealtimePalette.accent : hovered && isEnabled ?
            NSColor(srgbRed: 199 / 255, green: 208 / 255, blue: 248 / 255, alpha: 1) : NSColor(white: 0.95, alpha: 1)).cgColor
        // The overlay lives above the image; changing upload progress never reloads its source.
        let progress = reference?.uploadState == .uploading
        let error = reference?.uploadState == .error
        overlay.isHidden = !progress && !error
        overlay.frame = thumbnail.frame
        overlay.layer?.cornerRadius = overlay.bounds.height / 2
        overlay.layer?.backgroundColor = (error ? NSColor(srgbRed: 120 / 255, green: 20 / 255, blue: 20 / 255, alpha: 0.65) : .black.withAlphaComponent(0.55)).cgColor
        progressLabel.stringValue = error ? "Retry" : "\(Int((reference?.uploadProgress ?? 0) * 100))%"
        progressLabel.frame = NSRect(x: 0, y: error ? overlay.bounds.midY - 7 : overlay.bounds.midY + 6,
                                     width: overlay.bounds.width, height: 14)
    }

    private let overlay = RealtimeReferenceOverlay()
    private let progressLabel: NSTextField = {
        let label = realtimeLabel(size: 10, color: .white); label.alignment = .center; return label
    }()
}

private final class RealtimeReferenceOverlay: RealtimeCanvas {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Centers incomplete rows using the same dimensions as the Web reference grid.
final class RealtimeReferenceLayout: NSCollectionViewLayout {
    private var attributes: [NSCollectionViewLayoutAttributes] = []
    private var size = NSSize.zero

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }
        let width = collectionView.bounds.width
        let count = collectionView.numberOfItems(inSection: 0)
        let columns = max(1, Int((width + 14) / 90))
        let rows = (count + columns - 1) / columns
        size = NSSize(width: width, height: max(1, CGFloat(rows) * 98 - 14))
        attributes = (0..<count).map { index in
            let row = index / columns, rowCount = min(columns, count - row * columns)
            let rowWidth = CGFloat(rowCount) * 90 - 14
            let item = NSCollectionViewLayoutAttributes(forItemWith: IndexPath(item: index, section: 0))
            item.frame = NSRect(x: (width - rowWidth) / 2 + CGFloat(index % columns) * 90, y: CGFloat(row) * 98, width: 76, height: 84)
            return item
        }
    }

    override var collectionViewContentSize: NSSize { size }
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool { newBounds.width != size.width }
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        attributes.filter { $0.frame.intersects(rect) }
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        attributes.indices.contains(indexPath.item) ? attributes[indexPath.item] : nil
    }
}

final class RealtimeReferenceItem: NSCollectionViewItem {
    let button = RealtimeReferenceButton()
    override func loadView() { view = button }
    override func prepareForReuse() { super.prepareForReuse(); button.thumbnail.cancel(); button.onClick = nil }
}

/// Only changes to item identity reload the collection; toolbar and statistics updates preserve cells.
final class RealtimeReferenceList: RealtimeCanvas, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let scroll = NSScrollView()
    private let collection = NSCollectionView()
    private let itemID = NSUserInterfaceItemIdentifier("RealtimeReferenceItem")
    private var references: [RealtimeReference] = []
    private var selectedID: String?
    private var enabled = true
    var onUpload: (() -> Void)?
    var onSelect: ((RealtimeReference) -> Void)?

    override init(color: NSColor = .clear, radius: CGFloat = 0) {
        super.init(color: color, radius: radius)
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.scrollerStyle = .overlay
        collection.backgroundColors = [.clear]
        collection.collectionViewLayout = RealtimeReferenceLayout()
        collection.dataSource = self; collection.delegate = self
        collection.isSelectable = false
        collection.register(RealtimeReferenceItem.self, forItemWithIdentifier: itemID)
        scroll.documentView = collection
        addSubview(scroll)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout(); scroll.frame = bounds
        let width = scroll.contentSize.width
        let columns = max(1, Int((width + 14) / 90))
        let rows = (references.count + 1 + columns - 1) / columns
        let size = NSSize(width: width, height: max(scroll.contentSize.height, CGFloat(rows) * 98 - 14))
        if collection.frame.size != size {
            collection.setFrameSize(size)
            collection.collectionViewLayout?.invalidateLayout()
        }
    }

    func update(references: [RealtimeReference], selectedID: String?, enabled: Bool, dimmed: Bool) {
        let changed = self.references.map(\.id) != references.map(\.id)
        self.references = references; self.selectedID = selectedID; self.enabled = enabled
        alphaValue = dimmed ? 0.35 : 1
        if changed {
            collection.reloadData()
            needsLayout = true
            scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
        } else {
            for path in collection.indexPathsForVisibleItems() {
                if let item = collection.item(at: path) as? RealtimeReferenceItem { configure(item, at: path) }
            }
        }
    }

    func suspendImages() {
        for item in collection.visibleItems() { (item as? RealtimeReferenceItem)?.button.thumbnail.cancel() }
    }
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { references.count + 1 }
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: itemID, for: indexPath) as! RealtimeReferenceItem
        configure(item, at: indexPath); return item
    }
    private func configure(_ item: RealtimeReferenceItem, at path: IndexPath) {
        let reference = path.item == 0 ? nil : references[path.item - 1]
        item.button.configure(reference, selected: reference?.id == selectedID && selectedID != nil, enabled: enabled)
        item.button.onClick = { [weak self] in
            guard let self, self.enabled else { return }
            if let reference { self.onSelect?(reference) } else { self.onUpload?() }
        }
    }
}
