//
//  RealtimeComponents.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import AppKit
import ImageIO
import SwiftUI
import XmaxSDK

/// 与 Web X-Lab 对齐的浅色配色。
enum RealtimePalette {
    static let text = Color(red: 0.067, green: 0.075, blue: 0.094)
    static let secondary = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let surface = Color(red: 0.969, green: 0.973, blue: 0.980)
    static let border = Color(red: 0.898, green: 0.906, blue: 0.922)
    static let accent = Color(red: 0.184, green: 0.275, blue: 0.886)
}

/// 顶栏与主要操作共用的胶囊按钮。
struct RealtimeActionButtonStyle: ButtonStyle {
    enum Appearance { case standard, primary, destructive }

    var appearance: Appearance = .standard
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 17)
            .frame(height: 39)
            .foregroundStyle(foreground)
            .background {
                Capsule().fill(appearance == .primary ? RealtimePalette.accent : Color.white)
            }
            .overlay {
                Capsule().strokeBorder(
                    appearance == .primary ? RealtimePalette.accent :
                        (appearance == .destructive ? .red.opacity(0.22) : RealtimePalette.border)
                )
            }
            .shadow(color: .black.opacity(appearance == .primary ? 0.10 : 0.04), radius: 5, y: 2)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch appearance {
        case .standard: RealtimePalette.text
        case .primary: .white
        case .destructive: .red
        }
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

/// 独立显示一个视频轨道，Local 与 Result 始终各占一栏。
struct RealtimeVideoPanel: View {
    let title: String
    let track: RealtimeVideoTrack?
    let placeholder: String
    var isWaiting = false
    var showsWatermark = false

    var body: some View {
        ZStack {
            Color.black
            XmaxVideo(track: track, videoContentMode: .fit)
            if track == nil {
                VStack(spacing: 12) {
                    if isWaiting { ProgressView().controlSize(.small).tint(.white) }
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            VStack {
                HStack {
                    Spacer()
                    if showsWatermark {
                        Text("✦ Xmax")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                HStack {
                    Text(title)
                        .font(.system(size: 11))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                    Spacer()
                    if let format = track?.videoFormat {
                        Text("\(format.width) × \(format.height)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .foregroundStyle(.white.opacity(0.65))
            }
            .padding(15)
        }
        .aspectRatio(1920.0 / 1024.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title == "Local" ? "摄像头预览" : "生成结果")
    }
}

/// 参考图缩略图与选中反馈。
struct RealtimeReferenceButton: View {
    let reference: RealtimeReference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                RealtimeThumbnail(url: reference.thumbnailURL)
                .frame(width: 66, height: 66)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(isSelected ? RealtimePalette.accent : RealtimePalette.border, lineWidth: 2))
                Text(reference.name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? RealtimePalette.accent : RealtimePalette.secondary)
                    .lineLimit(1)
                    .frame(width: 86)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(reference.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 缩略图按实际显示尺寸解码并缓存，避免模式切换时重复加载大图。
struct RealtimeThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    RealtimePalette.surface
                    Image(systemName: "photo").foregroundStyle(RealtimePalette.secondary.opacity(0.5))
                }
            }
        }
        .accessibilityHidden(true)
        .task(id: url) {
            image = RealtimeThumbnailCache.images.object(forKey: url as NSURL)
            guard image == nil else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                          kCGImageSourceCreateThumbnailFromImageAlways: true,
                          kCGImageSourceCreateThumbnailWithTransform: true,
                          kCGImageSourceThumbnailMaxPixelSize: 160
                      ] as CFDictionary) else { return }
                let decoded = NSImage(
                    cgImage: thumbnail,
                    size: NSSize(width: CGFloat(thumbnail.width), height: CGFloat(thumbnail.height))
                )
                RealtimeThumbnailCache.images.setObject(decoded, forKey: url as NSURL)
                image = decoded
            } catch {
                // 保留占位图，重新进入该分类时可再次加载。
            }
        }
    }
}

@MainActor
private enum RealtimeThumbnailCache {
    static let images: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 100
        return cache
    }()
}
