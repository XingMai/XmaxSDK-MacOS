//
//  RealtimeComponents.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI
import XmaxSDK

/// 实时工作台共用的深色界面配色。
enum RealtimePalette {
    static let background = Color(red: 0.045, green: 0.052, blue: 0.068)
    static let sidebar = Color(red: 0.065, green: 0.074, blue: 0.093)
    static let surface = Color(red: 0.085, green: 0.096, blue: 0.119)
    static let field = Color(red: 0.054, green: 0.063, blue: 0.081)
    static let border = Color.white.opacity(0.075)
    static let secondary = Color(red: 0.55, green: 0.59, blue: 0.67)
    static let accent = Color(red: 0.48, green: 0.55, blue: 1)
    static let green = Color(red: 0.36, green: 0.83, blue: 0.66)
}

/// 统一显示连接或视频画面的当前状态。
struct RealtimeStatusBadge: View {
    let title: String
    var color: Color = RealtimePalette.secondary

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.09), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.14)))
    }
}

/// 独立承载一个视频轨道，空闲时显示清晰的操作提示。
struct RealtimeVideoPanel: View {
    let title: String
    let subtitle: String
    let symbol: String
    let track: RealtimeVideoTrack?
    let emptyTitle: String
    let emptyMessage: String
    let status: String
    var accent = RealtimePalette.green
    var isWaiting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(RealtimePalette.secondary)
                }
                Spacer(minLength: 8)
                RealtimeStatusBadge(
                    title: status,
                    color: track != nil || isWaiting ? accent : RealtimePalette.secondary
                )
            }
            .padding(16)

            ZStack {
                Color(red: 0.025, green: 0.032, blue: 0.045)
                if track == nil {
                    emptyState
                }
                XmaxVideo(track: track, videoContentMode: .fit)
                    .opacity(track == nil ? 0 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack(spacing: 6) {
                Image(systemName: track == nil ? "circle.dotted" : "waveform.path")
                    .font(.system(size: 10))
                Text(track == nil ? "等待视频信号" : "实时画面")
                    .font(.system(size: 10))
                Spacer()
                if let format = track?.videoFormat {
                    Text("\(format.width) × \(format.height)")
                        .font(.system(size: 10, design: .monospaced))
                } else {
                    Text("— × —").font(.system(size: 10, design: .monospaced))
                }
            }
            .foregroundStyle(RealtimePalette.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .background(RealtimePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RealtimePalette.border))
    }

    // 空闲与连接中画面
    private var emptyState: some View {
        ZStack {
            Canvas { context, size in
                var grid = Path()
                for x in stride(from: 0.0, through: size.width, by: 28) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0.0, through: size.height, by: 28) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
            }
            RadialGradient(
                colors: [accent.opacity(0.07), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 21)
                        .fill(accent.opacity(0.07))
                        .frame(width: 70, height: 70)
                        .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(accent.opacity(0.13)))
                    if isWaiting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(accent.opacity(0.8))
                    }
                }
                Text(isWaiting ? "正在准备生成画面" : emptyTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)
                Text(isWaiting ? "连接建立后，结果会显示在这里" : emptyMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(RealtimePalette.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(24)
        }
    }
}

/// 为主要操作和次要操作提供统一的按钮尺寸及反馈。
struct RealtimeActionButtonStyle: ButtonStyle {
    var isPrimary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16)
            .frame(height: 39)
            .foregroundStyle(isPrimary ? Color.white : Color.white.opacity(0.82))
            .background {
                if isPrimary {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(
                            colors: [RealtimePalette.accent, Color(red: 0.38, green: 0.43, blue: 0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                } else {
                    RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.055))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(isPrimary ? 0.12 : 0.07)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.32)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
