//
//  RealtimeView.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI
import XmaxSDK

/// 以独立双栏展示摄像头预览和生成结果的实时工作台。
struct RealtimeView: View {
    @StateObject private var controller = RealtimeSessionController()

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(RealtimePalette.border).frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(RealtimePalette.border).frame(width: 1)
                workspace
            }
        }
        .background(RealtimePalette.background)
        .foregroundStyle(.white.opacity(0.94))
        .preferredColorScheme(.dark)
        .task { await controller.refreshDevices() }
        .onDisappear { controller.viewDidDisappear() }
    }

    // 工作台标题
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(colors: [RealtimePalette.accent, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 11)
                )
            Text("X-Lab").font(.system(size: 23, weight: .semibold)).tracking(-0.7)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 19).padding(.horizontal, 5)
            Text("实时生成工作台")
                .font(.system(size: 12))
                .foregroundStyle(RealtimePalette.secondary)
            Spacer()
            RealtimeStatusBadge(title: connectionTitle, color: connectionColor)
            Text("v\(XmaxSDKInfo.version)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(RealtimePalette.secondary)
                .padding(.leading, 10)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 19)
    }

    // 连接与摄像头设置
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 5) {
                Text("工作区设置").font(.system(size: 14, weight: .semibold))
                Text("配置连接，选择你的画面来源")
                    .font(.system(size: 11))
                    .foregroundStyle(RealtimePalette.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("连接设置", symbol: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key").font(.system(size: 11, weight: .medium))
                    HStack(spacing: 8) {
                        Image(systemName: "key.horizontal")
                            .font(.system(size: 12))
                            .foregroundStyle(RealtimePalette.secondary)
                        SecureField("输入你的 API Key", text: $controller.apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .padding(11)
                    .background(RealtimePalette.field, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(RealtimePalette.border))
                    Text("本地预览可留空，生成前请先填写。")
                        .font(.system(size: 10))
                        .foregroundStyle(RealtimePalette.secondary)
                }
                .disabled(configurationLocked)
                VStack(alignment: .leading, spacing: 8) {
                    Text("生成模型").font(.system(size: 11, weight: .medium))
                    Picker("生成模型", selection: $controller.model) {
                        ForEach(RealtimeModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }
                .disabled(configurationLocked)
            }
            Rectangle().fill(RealtimePalette.border).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionLabel("输入设备", symbol: "video")
                    Spacer()
                    Button {
                        Task { await controller.refreshDevices() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RealtimePalette.secondary)
                            .frame(width: 26, height: 26)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.isBusy)
                    .help("刷新摄像头列表")
                    .accessibilityLabel("刷新摄像头列表")
                }
                Picker("摄像头", selection: $controller.selectedDeviceID) {
                    Text("系统默认摄像头").tag("")
                    ForEach(controller.devices) { device in
                        Text(device.name).tag(device.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.large)
                .disabled(configurationLocked)
                Text("发现 \(controller.devices.count) 个可用设备")
                    .font(.system(size: 10))
                    .foregroundStyle(RealtimePalette.secondary)
                if controller.localStream != nil {
                    Label("关闭预览后可更改连接设置", systemImage: "lock")
                        .font(.system(size: 10))
                        .foregroundStyle(RealtimePalette.secondary)
                        .padding(.top, 3)
                }
            }
            Spacer(minLength: 12)
            VStack(alignment: .leading, spacing: 12) {
                guideStep("01", title: "开启摄像头", detail: "先确认左侧的本地画面")
                guideStep("02", title: "写下生成描述", detail: "描述希望看到的内容与风格")
                guideStep("03", title: "开始实时生成", detail: "在右侧查看并比较生成结果")
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 6) {
                Image(systemName: "lock.shield").font(.system(size: 10))
                Text("API Key 仅在本次会话中使用")
                    .font(.system(size: 10))
            }
            .foregroundStyle(RealtimePalette.secondary.opacity(0.8))
        }
        .padding(22)
        .frame(width: 260)
        .background(RealtimePalette.sidebar)
    }

    // 左右独立画面与生成操作
    private var workspace: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("从镜头，到想象")
                        .font(.system(size: 23, weight: .semibold))
                        .tracking(-0.5)
                    Text("让真实画面与生成结果，同屏呈现。")
                        .font(.system(size: 12))
                        .foregroundStyle(RealtimePalette.secondary)
                }
                Spacer()
                Label("实时对照", systemImage: "rectangle.split.2x1")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(RealtimePalette.secondary)
                    .padding(.bottom, 2)
            }
            HStack(spacing: 16) {
                RealtimeVideoPanel(
                    title: "摄像头预览", subtitle: "CAMERA INPUT", symbol: "video",
                    track: controller.localStream?.videoTrack,
                    emptyTitle: "准备好你的镜头",
                    emptyMessage: "选择摄像头，开启本地预览",
                    status: controller.localStream == nil ? "未开启" : "预览中"
                )
                RealtimeVideoPanel(
                    title: "生成结果", subtitle: "AI OUTPUT", symbol: "sparkles",
                    track: controller.remoteStream?.videoTrack,
                    emptyTitle: "生成画面将在这里显示",
                    emptyMessage: "开启预览后，输入描述开始生成",
                    status: outputStatus,
                    accent: RealtimePalette.accent,
                    isWaiting: waitingForOutput
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 270)
            generationPanel
            if let message = controller.errorMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.52))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(26)
    }

    // 提示词与可选参考图
    private var generationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft").foregroundStyle(RealtimePalette.accent)
                Text("生成描述").fontWeight(.semibold)
                Spacer()
                Text(controller.state.connectionState == .generating ? "修改描述后可实时更新" : "描述内容、风格或你想改变的细节")
                    .font(.system(size: 10))
                    .foregroundStyle(RealtimePalette.secondary)
            }
            .font(.system(size: 12))
            TextEditor(text: $controller.prompt)
                .font(.system(size: 13))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 72)
                .background(RealtimePalette.field, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(RealtimePalette.border))
                .accessibilityLabel("生成描述")
            HStack(spacing: 8) {
                Image(systemName: "photo").foregroundStyle(RealtimePalette.secondary)
                TextField("参考图路径（可选）", text: $controller.referencePath)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                Text("可选").font(.system(size: 9)).foregroundStyle(RealtimePalette.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(RealtimePalette.field, in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 10) {
                Button {
                    Task {
                        if controller.localStream == nil {
                            await controller.startPreview()
                        } else {
                            await controller.close()
                        }
                    }
                } label: {
                    Label(controller.localStream == nil ? "开启预览" : "关闭预览", systemImage: controller.localStream == nil ? "video" : "stop.circle")
                }
                .buttonStyle(RealtimeActionButtonStyle())
                .disabled(controller.isBusy)
                if [.connected, .generating].contains(controller.state.connectionState) {
                    Button("断开生成") { Task { await controller.disconnect() } }
                        .buttonStyle(RealtimeActionButtonStyle())
                        .disabled(controller.isBusy)
                }
                Spacer()
                if controller.isBusy {
                    ProgressView().controlSize(.small).padding(.trailing, 4)
                }
                Button {
                    Task { await controller.startGeneration() }
                } label: {
                    Label(controller.state.connectionState == .generating ? "更新生成" : "开始生成", systemImage: "sparkles")
                        .frame(minWidth: 88)
                }
                .buttonStyle(RealtimeActionButtonStyle(isPrimary: true))
                .disabled(!canGenerate)
                .help(controller.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请先在连接设置中填写 API Key" : "使用当前描述开始或更新生成")
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(RealtimePalette.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RealtimePalette.border))
    }

    // 界面状态映射
    private var configurationLocked: Bool {
        controller.localStream != nil || controller.isBusy
    }

    private var canGenerate: Bool {
        [.ready, .connected, .generating].contains(controller.state.connectionState) &&
            !controller.isBusy && !controller.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var waitingForOutput: Bool {
        controller.isBusy && controller.remoteStream == nil &&
            [.connecting, .connected, .generating].contains(controller.state.connectionState)
    }

    private var outputStatus: String {
        if controller.remoteStream != nil { return "生成中" }
        return waitingForOutput ? "连接中" : "等待生成"
    }

    private var connectionTitle: String {
        switch controller.state.connectionState {
        case .idle: "待开始"
        case .preparing: "准备摄像头"
        case .ready: "预览就绪"
        case .connecting: "连接生成服务"
        case .connected: "已连接"
        case .generating: "正在生成"
        case .disconnecting: "正在断开"
        }
    }

    private var connectionColor: Color {
        switch controller.state.connectionState {
        case .ready: RealtimePalette.green
        case .connected, .generating: RealtimePalette.accent
        default: RealtimePalette.secondary
        }
    }

    /// 显示侧栏中的设置分组标题。
    ///
    /// - Parameters:
    ///   - title: 设置分组名称。
    ///   - symbol: 分组对应的系统图标。
    private func sectionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(RealtimePalette.secondary)
    }

    /// 显示简短的使用顺序，不占用视频操作区域。
    ///
    /// - Parameters:
    ///   - number: 步骤编号。
    ///   - title: 步骤名称。
    ///   - detail: 当前步骤的操作提示。
    private func guideStep(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(RealtimePalette.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 10, weight: .medium))
                Text(detail).font(.system(size: 9)).foregroundStyle(RealtimePalette.secondary)
            }
        }
    }
}
