//
//  RealtimeComponents.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit
import CoreText
import Kingfisher
import SwiftUI
import XmaxSDK

/// 与 Web X-Lab 对齐的浅色配色。
enum RealtimePalette {
    static let text = Color(red: 0.067, green: 0.075, blue: 0.094)
    static let secondary = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let surface = Color(red: 0.969, green: 0.973, blue: 0.980)
    static let border = Color(red: 0.898, green: 0.906, blue: 0.922)
    static let accent = Color(red: 47.0 / 255, green: 70.0 / 255, blue: 226.0 / 255)
    static let accentHover = Color(red: 36.0 / 255, green: 56.0 / 255, blue: 196.0 / 255)
}

/// 顶栏使用与 Web 相同的 DM Sans 字体，字体随示例应用分发。
@MainActor
enum RealtimeHeaderTypography {
    private static let fontName = "DMSans9pt-Regular"
    private static let registered: Bool = {
        guard let url = Bundle.main.url(forResource: "DMSans", withExtension: "ttf") else { return false }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return NSFont(name: fontName, size: 12) != nil
    }()

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registered ? .custom(fontName, size: size).weight(weight) : .system(size: size, weight: weight)
    }
}

/// 对应 Web 顶栏的渐变、外边框、内侧高光与两层阴影。
struct RealtimeHeaderPillSurface: View {
    var destructive = false
    var hovered = false

    private let shadowColor = Color(red: 16.0 / 255, green: 24.0 / 255, blue: 40.0 / 255)
    private let redBorder = Color(red: 224.0 / 255, green: 49.0 / 255, blue: 49.0 / 255)

    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [.white, bottomColor], startPoint: .top, endPoint: .bottom))
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.9), .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                    .padding(1)
            }
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))
            .shadow(color: shadowColor.opacity(hovered ? 0.1 : 0.08), radius: hovered ? 2 : 1, y: hovered ? 2 : 1)
            .shadow(
                color: (hovered && destructive ? redBorder : shadowColor).opacity(hovered ? (destructive ? 0.12 : 0.08) : 0.05),
                radius: hovered ? 8 : 6, y: hovered ? 6 : 4
            )
            .allowsHitTesting(false)
    }

    private var bottomColor: Color {
        if destructive {
            return hovered
                ? Color(red: 252.0 / 255, green: 232.0 / 255, blue: 232.0 / 255)
                : Color(red: 253.0 / 255, green: 242.0 / 255, blue: 242.0 / 255)
        }
        return Color(red: 243.0 / 255, green: 244.0 / 255, blue: 246.0 / 255)
    }

    private var borderColor: Color {
        if destructive { return redBorder.opacity(hovered ? 0.5 : 0.28) }
        return hovered
            ? Color(red: 201.0 / 255, green: 206.0 / 255, blue: 214.0 / 255)
            : Color(red: 226.0 / 255, green: 229.0 / 255, blue: 234.0 / 255)
    }
}

/// 顶栏按钮独立于舞台与输入区，尺寸和悬停反馈沿用 Web 的规则。
struct RealtimeHeaderButtonStyle: ButtonStyle {
    var height: CGFloat = 35
    var horizontalPadding: CGFloat = 14
    var iconOnly = false
    var destructive = false
    var muted = false

    func makeBody(configuration: Configuration) -> some View {
        RealtimeHeaderButtonBody(
            configuration: configuration, height: height,
            horizontalPadding: horizontalPadding, iconOnly: iconOnly,
            destructive: destructive, muted: muted
        )
    }
}

private struct RealtimeHeaderButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let height: CGFloat
    let horizontalPadding: CGFloat
    let iconOnly: Bool
    let destructive: Bool
    let muted: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(RealtimeHeaderTypography.font(size: destructive ? 13 : 12, weight: destructive ? .semibold : .regular))
            .foregroundStyle(destructive ? Color(red: 220.0 / 255, green: 38.0 / 255, blue: 38.0 / 255)
                             : (muted ? RealtimePalette.secondary : RealtimePalette.text))
            .padding(.horizontal, iconOnly ? 0 : horizontalPadding)
            .frame(width: iconOnly ? height : nil, height: height)
            .background(RealtimeHeaderPillSurface(destructive: destructive, hovered: isHovered && isEnabled))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

/// 会话模型与计时器使用 Web 中同样的 36pt 被动胶囊。
struct RealtimeHeaderPill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(RealtimeHeaderTypography.font(size: 13, weight: .medium))
            .foregroundStyle(RealtimePalette.secondary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(RealtimeHeaderPillSurface())
    }
}

/// 按 Web Key 图标的路径绘制，保持相同的方向和线宽。
struct RealtimeKeyIcon: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.addEllipse(in: CGRect(x: 2, y: 10, width: 11, height: 11))
                path.move(to: CGPoint(x: 11.39, y: 11.61))
                path.addLine(to: CGPoint(x: 21, y: 2))
                path.move(to: CGPoint(x: 15.5, y: 7.5))
                path.addLine(to: CGPoint(x: 18.5, y: 10.5))
                path.addLine(to: CGPoint(x: 22, y: 7))
                path.addLine(to: CGPoint(x: 19, y: 4))
            }
            .scale(x: geometry.size.width / 24, y: geometry.size.height / 24, anchor: .topLeading)
            .stroke(style: StrokeStyle(lineWidth: 2 * geometry.size.width / 24, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}

/// 与 Web 模型选择器一致的 12pt 下拉图标。
struct RealtimeHeaderChevron: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 3, y: 4.5))
            path.addLine(to: CGPoint(x: 6, y: 7.5))
            path.addLine(to: CGPoint(x: 9, y: 4.5))
        }
        .stroke(style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round))
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }
}

/// 弹层中的选择行，避免系统菜单忽略自定义顶栏按钮的外观。
struct RealtimeMenuOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundStyle(RealtimePalette.accent) }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(isSelected ? RealtimePalette.accent.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 启动页的棋盘格舞台，与 Web 示例保持一致。
struct RealtimeCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 38
            for row in 0...Int(size.height / cell) {
                for column in 0...Int(size.width / cell) {
                    let color = (row + column).isMultiple(of: 2)
                        ? Color(red: 0.263, green: 0.263, blue: 0.278)
                        : Color(red: 0.216, green: 0.216, blue: 0.231)
                    context.fill(
                        Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                        with: .color(color)
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// 独立显示一个视频轨道，统计固定在左上角，标签位于左下角。
struct RealtimeVideoPanel: View {
    let title: String
    let track: RealtimeVideoTrack?
    let placeholder: String
    var showsWatermark = false
    var statistics: [RealtimeStatisticsGroup] = []

    var body: some View {
        ZStack {
            Color.black
            XmaxVideo(track: track)
            if !placeholder.isEmpty {
                Text(placeholder)
                    .font(RealtimeHeaderTypography.font(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                    .allowsHitTesting(false)
            }
        }
        .aspectRatio(1920.0 / 1024.0, contentMode: .fit)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(statistics) { group in RealtimeStatisticsPanel(group: group) }
            }
            .padding(.top, 12).padding(.leading, 14)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if showsWatermark {
                Text("✦ Xmax")
                    .font(RealtimeHeaderTypography.font(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 12).padding(.trailing, 16)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(title)
                .font(RealtimeHeaderTypography.font(size: 12))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 14).padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// 参考图缩略图复用同一份本地预览、进度和失败重试状态。
struct RealtimeReferenceThumbnail: View {
    let reference: RealtimeReference
    var loadsThumbnail = true

    var body: some View {
        RealtimeThumbnail(url: reference.thumbnailURL, data: reference.thumbnailData, cacheKey: reference.id, enabled: loadsThumbnail)
            .clipShape(Circle())
            .overlay {
                if reference.uploadState != .ready {
                    Circle().fill(reference.uploadState == .error ? Color(red: 120.0 / 255, green: 20.0 / 255, blue: 20.0 / 255).opacity(0.65) : .black.opacity(0.55))
                    if reference.uploadState == .error {
                        Text("Retry").font(RealtimeHeaderTypography.font(size: 10)).foregroundStyle(.white)
                    } else {
                        VStack(spacing: 4) {
                            RealtimeSpinner(size: 16)
                            if reference.uploadProgress > 0 {
                                Text("\(Int(reference.uploadProgress * 100))%")
                                    .font(RealtimeHeaderTypography.font(size: 10)).foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
    }
}

/// 参考图圆形描边、悬停和选中反馈沿用 Web 的尺寸与颜色。
struct RealtimeReferenceButton: View {
    let reference: RealtimeReference
    let isSelected: Bool
    let action: () -> Void
    var loadsThumbnail = true
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RealtimeReferenceThumbnail(reference: reference, loadsThumbnail: loadsThumbnail)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().strokeBorder(isSelected ? RealtimePalette.accent :
                        hovered && isEnabled ? Color(red: 199.0 / 255, green: 208.0 / 255, blue: 248.0 / 255) :
                        Color(red: 243.0 / 255, green: 244.0 / 255, blue: 246.0 / 255), lineWidth: 2))
                Text(reference.name)
                    .font(RealtimeHeaderTypography.font(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? RealtimePalette.accent : RealtimePalette.secondary)
                    .lineLimit(1).frame(width: 76, height: 14)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RealtimeUnstyledButtonStyle())
        .onHover { hovered = $0 }
        .help(reference.uploadError.map { $0 + " — Click to retry" } ?? reference.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Kingfisher 管理图片加载与缓存；仅本地上传预览需要降采样。
struct RealtimeThumbnail: View {
    let url: URL
    var data: Data? = nil
    var cacheKey: String? = nil
    var enabled = true
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Group {
            if enabled {
                image
                    .placeholder { placeholder }
                    .onFailureView { placeholder }
                    .scaleFactor(displayScale)
                    .backgroundDecode()
                    .cacheMemoryOnly(data != nil)
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .accessibilityHidden(true)
    }

    private var image: KFImage {
        let image = KFImage(source: source)
        if data != nil || url.isFileURL {
            return image.downsampling(size: CGSize(width: 80, height: 80))
        }
        return image
    }

    private var source: Source {
        if let data {
            return .provider(RawImageDataProvider(data: data, cacheKey: cacheKey ?? url.absoluteString))
        }
        if url.isFileURL {
            return .provider(LocalFileImageDataProvider(fileURL: url, cacheKey: cacheKey))
        }
        return .network(KF.ImageResource(downloadURL: url))
    }

    private var placeholder: some View {
        ZStack {
            RealtimePalette.surface
            Image(systemName: "photo").foregroundStyle(RealtimePalette.secondary.opacity(0.5))
        }
    }
}

/// Web 的 18pt 白色环形 loading，0.8 秒一周；减少动态效果时保持静止。
struct RealtimeSpinner: View {
    var size: CGFloat = 18
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false

    var body: some View {
        Circle().stroke(.white.opacity(0.35), lineWidth: 2)
            .overlay(Circle().trim(from: 0, to: 0.25).stroke(.white, lineWidth: 2))
            .frame(width: size - 2, height: size - 2)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .frame(width: size, height: size)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spinning = true }
            }
            .accessibilityHidden(true)
    }
}

/// 启动按钮有独立的禁用语义：loading 保持原有蓝色、阴影与透明度。
struct RealtimeStartButton: View {
    let isLoading: Bool
    let viewportWidth: CGFloat
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { RealtimeSpinner() }
                else { RealtimeWebIcon(kind: .camera).frame(width: 20, height: 20) }
                Text(isLoading ? "Starting…" : "Start Camera")
            }
            .font(RealtimeHeaderTypography.font(size: min(18, max(15, viewportWidth * 0.003 + 12)), weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, min(16, max(12, viewportWidth * 0.0028 + 9)))
            .padding(.horizontal, min(40, max(25, viewportWidth * 0.0075 + 18)))
            .background(hovered && !isLoading ? RealtimePalette.accentHover : RealtimePalette.accent, in: Capsule())
            .shadow(color: RealtimePalette.accent.opacity(0.35), radius: 15, y: 10)
            .contentShape(Capsule())
        }
        .buttonStyle(RealtimeUnstyledButtonStyle())
        .disabled(isLoading)
        .onHover { hovered = $0 }
        .accessibilityLabel(isLoading ? "Starting…" : "Start Camera")
    }
}

/// 会话工具按钮与 Web 的统计蓝色、插帧金色激活态一致。
struct RealtimeSessionToolStyle: ButtonStyle {
    enum Kind { case volume, statistics, interpolation }
    var active = false
    var kind = Kind.volume

    func makeBody(configuration: Configuration) -> some View {
        RealtimeSessionToolBody(configuration: configuration, active: active, kind: kind)
    }
}

private struct RealtimeSessionToolBody: View {
    let configuration: ButtonStyleConfiguration
    let active: Bool
    let kind: RealtimeSessionToolStyle.Kind
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        configuration.label
            .font(RealtimeHeaderTypography.font(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.leading, kind == .interpolation ? 12 : 0)
            .padding(.trailing, kind == .interpolation ? 15 : 0)
            .frame(width: kind == .interpolation ? nil : 36, height: 36)
            .background {
                if active && kind == .statistics {
                    Capsule().fill(Color(red: 238.0 / 255, green: 241.0 / 255, blue: 1))
                        .overlay(Capsule().strokeBorder(Color(red: 215.0 / 255, green: 221.0 / 255, blue: 251.0 / 255)))
                } else if active && kind == .interpolation {
                    Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 250.0 / 255, blue: 240.0 / 255),
                                                           Color(red: 1, green: 240.0 / 255, blue: 202.0 / 255)],
                                                  startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(Color(red: 240.0 / 255, green: 207.0 / 255, blue: 136.0 / 255)))
                } else { RealtimeHeaderPillSurface(hovered: hovered && isEnabled) }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
            .onHover { hovered = $0 }
    }

    private var foreground: Color {
        if active && kind == .statistics { return RealtimePalette.accent }
        if active && kind == .interpolation { return Color(red: 169.0 / 255, green: 102.0 / 255, blue: 8.0 / 255) }
        if active || (hovered && isEnabled) { return RealtimePalette.text }
        return Color(red: 139.0 / 255, green: 145.0 / 255, blue: 157.0 / 255)
    }
}

struct RealtimeModeTabStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        RealtimeModeTabBody(configuration: configuration, isSelected: isSelected)
    }
}

private struct RealtimeModeTabBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @State private var hovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(RealtimeHeaderTypography.font(size: 13.5, weight: .medium)).tracking(0.135)
            .foregroundStyle(isSelected || hovered ? RealtimePalette.text : RealtimePalette.secondary)
            .padding(.horizontal, 22).frame(height: 34)
            .background {
                Capsule().fill(isSelected ? .white : (hovered ? .white.opacity(0.65) : .clear))
                    .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 4, y: 2)
                    .shadow(color: .black.opacity(isSelected ? 0.06 : 0), radius: 0.75, y: 0.5)
            }
            .contentShape(Capsule()).opacity(isEnabled ? 1 : 0.5)
            .onHover { hovered = $0 }
            .animation(.easeInOut(duration: 0.22), value: hovered)
    }
}

/// 自由输入的上传和提交按钮均为 44pt 圆形。
struct RealtimePromptButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        RealtimePromptButtonBody(configuration: configuration, primary: primary)
    }
}

private struct RealtimePromptButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let primary: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        configuration.label
            .foregroundStyle(primary ? .white : hovered && isEnabled ? RealtimePalette.text : RealtimePalette.secondary)
            .frame(width: 44, height: 44)
            .background(primary ? (hovered && isEnabled ? RealtimePalette.accentHover : RealtimePalette.accent) :
                            (hovered && isEnabled ? Color.gray.opacity(0.08) : .clear), in: Circle())
            .overlay(Circle().strokeBorder(primary ? .clear : hovered && isEnabled ?
                Color(red: 201.0 / 255, green: 206.0 / 255, blue: 214.0 / 255) : RealtimePalette.border))
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Circle())
            .onHover { hovered = $0 }
            .animation(.easeInOut(duration: 0.2), value: hovered)
    }
}

/// Web 统计面板只接收已格式化的值；未公开或尚未收到的指标统一显示 —。
struct RealtimeStatisticsGroup: Identifiable {
    let id: String
    var rows: [RealtimeStatisticsRow]
}

struct RealtimeStatisticsRow: Identifiable {
    let id: String
    var value = "—"
    var help = ""
    var total = false
}

struct RealtimeStatisticsPanel: View {
    let group: RealtimeStatisticsGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(group.rows) { row in
                if row.total { Divider().overlay(.white.opacity(0.18)).padding(.vertical, 5) }
                HStack(spacing: 16) {
                    Text(row.id).font(RealtimeHeaderTypography.font(size: 11, weight: row.total ? .semibold : .regular))
                    Spacer(minLength: 0)
                    Text(row.value).font(.system(size: 11, weight: row.total ? .semibold : .regular, design: .monospaced))
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .frame(height: 16.5)
                .help(row.help)
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10).padding(.vertical, 8)
        .fixedSize(horizontal: true, vertical: true)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12)))
        .accessibilityElement(children: .contain).accessibilityLabel(group.id)
    }
}

extension RealtimeSessionController {
    var localStatisticsPanels: [RealtimeStatisticsGroup] {
        [
            .init(id: "Launch timing", rows: [
                .init(id: "Camera access", help: "Not exposed by the macOS SDK"),
                .init(id: "Create session", help: "Not exposed by the macOS SDK"),
                .init(id: "RTC join", help: "Not exposed by the macOS SDK"),
                .init(id: "Publish local stream", help: "Not exposed by the macOS SDK"),
                .init(id: "First frame", help: "Not exposed by the macOS SDK"),
                .init(id: "Render warmup", help: "Not exposed by the macOS SDK"),
                .init(id: "Total startup", help: "Not exposed by the macOS SDK", total: true)
            ]),
            .init(id: "Uplink video statistics", rows: [
                .init(id: "Uplink resolution", value: resolution(uplinkStatistics?.width, uplinkStatistics?.height)),
                .init(id: "Uplink frame rate", value: metric(uplinkStatistics?.sendFrameRate, "fps")),
                .init(id: "Uplink bitrate", value: metric(uplinkStatistics?.bitrateKbps, "kbps"))
            ]),
            .init(id: "Uplink network and latency", rows: [
                .init(id: "Uplink packet loss", value: metric(uplinkStatistics?.packetLossPercent, "%"),
                      help: "Packet loss from this SDK to the RTC cloud, not local preview loss"),
                .init(id: "Uplink network quality", value: quality(networkQuality?.uplink)),
                .init(id: "Uplink RTT", help: "Not exposed by the macOS SDK")
            ])
        ]
    }

    var remoteStatisticsPanels: [RealtimeStatisticsGroup] {
        [
            .init(id: "Downlink video statistics", rows: [
                .init(id: "Downlink resolution", value: resolution(downlinkStatistics?.width, downlinkStatistics?.height)),
                .init(id: "Downlink frame rate", value: metric(downlinkStatistics?.renderFrameRate, "fps")),
                .init(id: "Downlink bitrate", value: metric(downlinkStatistics?.bitrateKbps, "kbps"))
            ]),
            .init(id: "Downlink network and latency", rows: [
                .init(id: "Playback buffer delay", help: "Not exposed by the macOS SDK"),
                .init(id: "Downlink packet loss", value: metric(downlinkStatistics?.packetLossPercent, "%")),
                .init(id: "Downlink network quality", value: quality(networkQuality?.downlink)),
                .init(id: "RTT (cloud)", help: "Not exposed by the macOS SDK"),
                .init(id: "E2E (RTC estimate)", value: metric(downlinkStatistics?.endToEndDelayMs, "ms"))
            ])
        ]
    }

    private func metric(_ value: Int?, _ unit: String) -> String { value.map { "\($0) \(unit)" } ?? "—" }
    private func resolution(_ width: Int?, _ height: Int?) -> String {
        guard let width, let height else { return "—" }
        return "\(width) × \(height)"
    }
    private func quality(_ level: RealtimeNetworkQualityLevel?) -> String {
        guard let level else { return "—" }
        return level == .veryBad ? "Very bad" : level.rawValue
    }
}

/// 沿用 Web 图标的 24×24 坐标，避免 SF Symbols 产生不同轮廓。
struct RealtimeWebIcon: View {
    enum Kind { case camera, microphone, statistics, muted, volume, volumeLow, lightning, plus, arrow, globe, socialX, wechat }
    let kind: Kind

    var body: some View {
        GeometryReader { geometry in
            let transform = CGAffineTransform(scaleX: geometry.size.width / 24, y: geometry.size.height / 24)
            if kind == .lightning || kind == .socialX || kind == .wechat {
                iconPath.applying(transform).fill(style: FillStyle(eoFill: true))
            } else {
                iconPath.applying(transform).stroke(style: StrokeStyle(
                    lineWidth: (kind == .arrow ? 3 : kind == .plus || kind == .microphone ? 2 : 1.8) * geometry.size.width / 24,
                    lineCap: .round, lineJoin: .round
                ))
            }
        }.accessibilityHidden(true)
    }

    private var iconPath: Path {
        Path { p in
            func line(_ points: [CGPoint]) {
                guard let first = points.first else { return }
                p.move(to: first)
                for point in points.dropFirst() { p.addLine(to: point) }
            }
            func points(_ values: [(CGFloat, CGFloat)]) -> [CGPoint] { values.map { CGPoint(x: $0.0, y: $0.1) } }
            switch kind {
            case .camera:
                p.addRoundedRect(in: CGRect(x: 2, y: 6, width: 14, height: 12), cornerSize: CGSize(width: 3, height: 3))
                line(points([(16,10),(22,6.5),(22,17.5),(16,14)]))
            case .microphone:
                p.addRoundedRect(in: CGRect(x: 9, y: 2, width: 6, height: 13), cornerSize: CGSize(width: 3, height: 3))
                p.move(to: CGPoint(x: 19,y: 10)); p.addLine(to: CGPoint(x: 19,y: 12))
                p.addCurve(to: CGPoint(x: 5,y: 12), control1: CGPoint(x: 19,y: 21.3), control2: CGPoint(x: 5,y: 21.3))
                p.addLine(to: CGPoint(x: 5,y: 10)); line(points([(12,19),(12,22)]))
            case .statistics:
                line(points([(4,4),(4,20),(20,20)])); line(points([(8,15),(8,11)]))
                line(points([(13,15),(13,7)])); line(points([(18,15),(18,9)]))
            case .muted, .volume, .volumeLow:
                line(points([(11,4),(6,8),(3,8),(3,16),(6,16),(11,20),(11,4)]))
                if kind == .muted {
                    line(points([(16,9),(22,15)])); line(points([(22,9),(16,15)]))
                } else {
                    p.move(to: CGPoint(x: 15,y: 8))
                    p.addCurve(to: CGPoint(x: 15,y: 16), control1: CGPoint(x: 18,y: 10), control2: CGPoint(x: 18,y: 14))
                    if kind == .volume {
                        p.move(to: CGPoint(x: 18,y: 5))
                        p.addCurve(to: CGPoint(x: 18,y: 19), control1: CGPoint(x: 24,y: 9), control2: CGPoint(x: 24,y: 15))
                    }
                }
            case .lightning:
                line(points([(13.7,2.3),(4.2,13),(10.4,14.2),(9.5,21.7),(19.8,11),(12.9,9.8),(13.7,2.3)])); p.closeSubpath()
            case .plus: line(points([(12,4),(12,20)])); line(points([(4,12),(20,12)]))
            case .arrow: line(points([(4,12),(20,12)])); line(points([(14,6),(20,12),(14,18)]))
            case .globe:
                p.addEllipse(in: CGRect(x: 2,y: 2,width: 20,height: 20)); line(points([(2,12),(22,12)]))
                p.move(to: CGPoint(x: 12,y: 2))
                p.addCurve(to: CGPoint(x: 12,y: 22), control1: CGPoint(x: 17.3,y: 7), control2: CGPoint(x: 17.3,y: 17))
                p.addCurve(to: CGPoint(x: 12,y: 2), control1: CGPoint(x: 6.7,y: 17), control2: CGPoint(x: 6.7,y: 7))
            case .socialX:
                line(points([(18.244,2.25),(21.552,2.25),(14.325,10.51),(22.827,21.75),(16.17,21.75),(10.956,14.933),(4.99,21.75),(1.68,21.75),(9.41,12.915),(1.254,2.25),(8.08,2.25),(12.793,8.481),(18.244,2.25)])); p.closeSubpath()
                line(points([(17.083,19.77),(18.916,19.77),(6.95,4.126),(5.117,4.126),(17.083,19.77)])); p.closeSubpath()
            case .wechat:
                p.move(to: CGPoint(x: 9.3, y: 4))
                p.addCurve(to: CGPoint(x: 2.6, y: 9.9), control1: CGPoint(x: 5.6, y: 4), control2: CGPoint(x: 2.6, y: 6.6))
                p.addCurve(to: CGPoint(x: 5.2, y: 14.5), control1: CGPoint(x: 2.6, y: 11.8), control2: CGPoint(x: 3.6, y: 13.4))
                p.addLine(to: CGPoint(x: 4.5, y: 16.7)); p.addLine(to: CGPoint(x: 6.9, y: 15.5))
                p.addCurve(to: CGPoint(x: 9.3, y: 15.8), control1: CGPoint(x: 7.6, y: 15.7), control2: CGPoint(x: 8.4, y: 15.8))
                p.addLine(to: CGPoint(x: 9.8, y: 15.8))
                p.addCurve(to: CGPoint(x: 9.6, y: 14.5), control1: CGPoint(x: 9.7, y: 15.4), control2: CGPoint(x: 9.6, y: 14.9))
                p.addCurve(to: CGPoint(x: 16, y: 8.9), control1: CGPoint(x: 9.6, y: 11.4), control2: CGPoint(x: 12.5, y: 8.9))
                p.addLine(to: CGPoint(x: 16.3, y: 8.9))
                p.addCurve(to: CGPoint(x: 9.3, y: 4), control1: CGPoint(x: 15.7, y: 6.2), control2: CGPoint(x: 12.8, y: 4))
                p.closeSubpath()
                p.addEllipse(in: CGRect(x: 6.4, y: 7.2, width: 1.8, height: 1.8))
                p.addEllipse(in: CGRect(x: 10.8, y: 7.2, width: 1.8, height: 1.8))
                p.move(to: CGPoint(x: 15.8, y: 9.9))
                p.addCurve(to: CGPoint(x: 10.2, y: 14.5), control1: CGPoint(x: 12.7, y: 9.9), control2: CGPoint(x: 10.2, y: 11.9))
                p.addCurve(to: CGPoint(x: 15.8, y: 19.1), control1: CGPoint(x: 10.2, y: 17), control2: CGPoint(x: 12.7, y: 19.1))
                p.addCurve(to: CGPoint(x: 17.7, y: 18.8), control1: CGPoint(x: 16.4, y: 19.1), control2: CGPoint(x: 17.1, y: 19))
                p.addLine(to: CGPoint(x: 19.7, y: 19.8)); p.addLine(to: CGPoint(x: 19.2, y: 18))
                p.addCurve(to: CGPoint(x: 21.4, y: 14.5), control1: CGPoint(x: 20.5, y: 17.2), control2: CGPoint(x: 21.4, y: 15.9))
                p.addCurve(to: CGPoint(x: 15.8, y: 9.9), control1: CGPoint(x: 21.4, y: 12), control2: CGPoint(x: 18.9, y: 9.9))
                p.closeSubpath()
                p.addEllipse(in: CGRect(x: 13.4, y: 12.4, width: 1.6, height: 1.6))
                p.addEllipse(in: CGRect(x: 16.6, y: 12.4, width: 1.6, height: 1.6))
                p = p.applying(CGAffineTransform(a: 1.15, b: 0, c: 0, d: 1.15, tx: -1.8, ty: -1.8))
            }
        }
    }
}

/// 避免 macOS 的 plain 样式对 disabled 内容额外叠加半透明。
struct RealtimeUnstyledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

/// Web 每行参考图居中，包括不足一整行的最后一行。
struct RealtimeReferenceGrid: Layout {
    private let itemWidth: CGFloat = 76
    private let gap: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? itemWidth
        let columns = max(1, Int((width + gap) / (itemWidth + gap)))
        let rows = (subviews.count + columns - 1) / columns
        return CGSize(width: width, height: CGFloat(rows) * 84 + CGFloat(max(0, rows - 1)) * gap)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = max(1, Int((bounds.width + gap) / (itemWidth + gap)))
        for index in subviews.indices {
            let row = index / columns
            let rowCount = min(columns, subviews.count - row * columns)
            let rowWidth = CGFloat(rowCount) * itemWidth + CGFloat(max(0, rowCount - 1)) * gap
            let x = bounds.minX + (bounds.width - rowWidth) / 2 + CGFloat(index % columns) * (itemWidth + gap)
            subviews[index].place(at: CGPoint(x: x, y: bounds.minY + CGFloat(row) * (84 + gap)),
                                 proposal: ProposedViewSize(width: itemWidth, height: 84))
        }
    }
}

/// 页面仅在进入时渐入上浮，旧页面立即移除，不叠加两页内容。
struct RealtimePageEntry: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content.opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .onAppear { withAnimation(.easeOut(duration: 0.45)) { appeared = true } }
    }
}
