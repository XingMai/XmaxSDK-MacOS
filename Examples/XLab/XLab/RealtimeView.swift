//
//  RealtimeView.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI
import UniformTypeIdentifiers
import XmaxSDK

/// 对齐 Web X-Lab 的启动页、顶栏设置和双屏会话布局。
struct RealtimeView: View {
    @StateObject private var controller = RealtimeSessionController()
    @State private var keyEditorOpen = false
    @State private var modelPickerOpen = false
    @State private var cameraPickerOpen = false
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if controller.localStream == nil {
                landingPage
            } else {
                Spacer(minLength: 20)
                RealtimeSessionWorkspace(controller: controller)
                Spacer(minLength: 20)
            }
            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(.white)
        .foregroundStyle(RealtimePalette.text)
        .preferredColorScheme(.light)
        .tint(RealtimePalette.accent)
        .overlay(alignment: .bottom) {
            if let message = controller.errorMessage {
                errorToast(message).padding(.bottom, 55)
            }
        }
        .task { await controller.refreshDevices() }
        .task(id: controller.errorMessage) {
            guard controller.errorMessage != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            controller.dismissError()
        }
        .onDisappear { controller.viewDidDisappear() }
    }

    // 品牌与会话设置
    private var header: some View {
        HStack(spacing: 14) {
            Image("XmaxWordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 154, height: 39)
                .accessibilityLabel("Xmax AI")
            Spacer()
            if controller.localStream == nil {
                modelPicker
                keyButton
            } else {
                Text(controller.model.displayName)
                    .font(.system(size: 12))
                    .foregroundStyle(RealtimePalette.secondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(controller.state.connectionState == .generating ? .green : RealtimePalette.secondary)
                        .frame(width: 5, height: 5)
                    Text(connectionTitle).font(.system(size: 11))
                }
                .foregroundStyle(RealtimePalette.secondary)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsed(at: context.date))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 15)
                        .frame(height: 39)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().strokeBorder(RealtimePalette.border))
                }
                Button { Task { await controller.close() } } label: {
                    Label("Stop Session", systemImage: "stop.fill")
                }
                .buttonStyle(RealtimeActionButtonStyle(appearance: .destructive))
                .disabled(controller.isBusy)
                .help("结束生成并关闭摄像头")
            }
        }
        .frame(height: 52)
    }

    private var modelPicker: some View {
        Button { modelPickerOpen.toggle() } label: {
            HStack(spacing: 10) {
                Text(controller.model.displayName)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12))
            .foregroundStyle(RealtimePalette.text)
            .padding(.horizontal, 17)
            .frame(height: 39)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(RealtimePalette.border))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(controller.isBusy)
        .accessibilityLabel("生成模型")
        .popover(isPresented: $modelPickerOpen, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                ForEach(RealtimeModel.allCases, id: \.self) { model in
                    RealtimeMenuOption(title: model.displayName, isSelected: controller.model == model) {
                        controller.model = model
                        modelPickerOpen = false
                    }
                }
            }
            .padding(8)
            .frame(width: 240)
        }
    }

    private var keyButton: some View {
        Button { keyEditorOpen.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: "key")
                if controller.hasAPIKey { Text("Key 已设置") }
            }
        }
        .buttonStyle(RealtimeActionButtonStyle())
        .disabled(controller.isBusy)
        .help("设置 API Key")
        .accessibilityLabel("设置 API Key")
        .popover(isPresented: $keyEditorOpen, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("API Key").font(.system(size: 13, weight: .semibold))
                SecureField("输入你的 API Key", text: $controller.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .focused($keyFieldFocused)
                    .onSubmit { keyEditorOpen = false }
                    .accessibilityLabel("API Key")
                Text("仅在本次会话中使用，不保存到磁盘。")
                    .font(.system(size: 11))
                    .foregroundStyle(RealtimePalette.secondary)
                HStack {
                    Spacer()
                    Button("完成") { keyEditorOpen = false }
                        .buttonStyle(RealtimeActionButtonStyle(appearance: .primary))
                }
            }
            .padding(18)
            .frame(width: 300)
            .onAppear { keyFieldFocused = true }
        }
    }

    // 启动入口：一键生成与本地预览共用摄像头生命周期
    private var landingPage: some View {
        GeometryReader { geometry in
            VStack(spacing: 28) {
                Text("Reimagining Live Video with Xmax")
                    .font(.system(size: 34, weight: .medium))
                    .tracking(-1.2)
                ZStack {
                    RealtimeCheckerboard()
                    VStack(spacing: 18) {
                        Button {
                            if !controller.hasAPIKey { keyEditorOpen = true }
                            Task { await controller.startPreview(autoGenerate: true) }
                        } label: {
                            HStack(spacing: 10) {
                                if controller.isBusy {
                                    ProgressView().controlSize(.small).tint(.white)
                                } else {
                                    Image(systemName: "video")
                                }
                                Text(controller.isBusy ? "Starting…" : "Start Camera")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(RealtimeActionButtonStyle(appearance: .primary))
                        .disabled(controller.isBusy)
                        .help("开启摄像头并使用首个角色预设开始生成")
                        cameraPicker
                        Button("仅本地预览") {
                            Task { await controller.startPreview() }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .disabled(controller.isBusy)
                    }
                    VStack {
                        Spacer()
                        Text("选择摄像头，开启你的实时创作。")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 22)
                    }
                }
                .aspectRatio(1920.0 / 1024.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                Text("XmaxSDK \(XmaxSDKInfo.version) · macOS")
                    .font(.system(size: 10))
                    .foregroundStyle(RealtimePalette.secondary.opacity(0.75))
            }
            .frame(width: min(780, geometry.size.width - 80))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var cameraPicker: some View {
        Button { cameraPickerOpen.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: "video")
                Text(controller.devices.first { $0.id == controller.selectedDeviceID }?.name ?? "系统默认摄像头")
                    .lineLimit(1)
                    .frame(maxWidth: 230)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.black.opacity(0.25), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .disabled(controller.isBusy)
        .accessibilityLabel("选择摄像头")
        .popover(isPresented: $cameraPickerOpen, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                RealtimeMenuOption(title: "系统默认摄像头", isSelected: controller.selectedDeviceID.isEmpty) {
                    controller.selectedDeviceID = ""
                    cameraPickerOpen = false
                }
                ForEach(controller.devices) { device in
                    RealtimeMenuOption(title: device.name, isSelected: controller.selectedDeviceID == device.id) {
                        controller.selectedDeviceID = device.id
                        cameraPickerOpen = false
                    }
                }
                Divider().padding(.vertical, 5)
                Button("刷新摄像头列表") { Task { await controller.refreshDevices() } }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .padding(9)
            }
            .padding(8)
            .frame(width: 290)
        }
    }

    private var footer: some View {
        HStack(spacing: 22) {
            Text("© 2026 XMAX.AI PTE. LTD.")
                .font(.system(size: 10))
            Spacer()
            Link("GitHub", destination: URL(string: "https://github.com/XingMai/XmaxSDK-MacOS")!)
            Link("API Platform", destination: URL(string: "https://platform.xmaxai.com")!)
        }
        .font(.system(size: 11))
        .foregroundStyle(RealtimePalette.secondary)
        .padding(.top, 12)
    }

    private var connectionTitle: String {
        switch controller.state.connectionState {
        case .idle: "未连接"
        case .preparing: "准备摄像头"
        case .ready: controller.hasAPIKey ? "预览就绪" : "本地预览"
        case .connecting: "连接中"
        case .connected: "已连接"
        case .generating: "实时生成中"
        case .disconnecting: "结束会话"
        }
    }

    /// 会话计时从摄像头创建成功开始，结束后归零。
    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(controller.sessionStartedAt ?? date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func errorToast(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            Text(message).font(.system(size: 12)).lineLimit(3).textSelection(.enabled)
            Spacer(minLength: 10)
            Button { controller.dismissError() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭错误提示")
        }
        .padding(15)
        .frame(maxWidth: 580)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(RealtimePalette.border))
        .shadow(color: .black.opacity(0.1), radius: 18, y: 6)
    }
}

/// 双屏与模式编辑区独立于启动页，切换模式时不重新绑定视频轨道。
struct RealtimeSessionWorkspace: View {
    @ObservedObject var controller: RealtimeSessionController
    @State private var importPresented = false
    @State private var uploadMode = RealtimeExampleMode.charx

    var body: some View {
        VStack(spacing: 26) {
            HStack(spacing: 24) {
                RealtimeVideoPanel(
                    title: "Local", track: controller.localStream?.videoTrack,
                    placeholder: "等待摄像头画面…"
                )
                RealtimeVideoPanel(
                    title: "Result", track: controller.remoteStream?.videoTrack,
                    placeholder: controller.isBusy ? "正在准备生成画面…" : "选择参考图，开始实时生成",
                    isWaiting: controller.isBusy, showsWatermark: true
                )
            }
            modeTabs
            ZStack {
                if controller.activeMode == .free {
                    promptEditor
                } else {
                    referenceList(for: controller.activeMode)
                        .id(controller.activeMode)
                }
            }
            .frame(height: 204)
        }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.image]) { result in
            if case let .success(url) = result {
                let mode = uploadMode
                Task { await controller.uploadReference(at: url, mode: mode) }
            }
        }
    }

    private var modeTabs: some View {
        HStack(spacing: 4) {
            ForEach(RealtimeExampleMode.allCases) { mode in
                Button { controller.activeMode = mode } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: controller.activeMode == mode ? .semibold : .medium))
                        .foregroundStyle(controller.activeMode == mode ? RealtimePalette.text : RealtimePalette.secondary)
                        .padding(.horizontal, 22)
                        .frame(height: 35)
                        .background {
                            if controller.activeMode == mode {
                                Capsule().fill(.white).shadow(color: .black.opacity(0.09), radius: 4, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(controller.activeMode == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RealtimePalette.surface, in: Capsule())
        .disabled(controller.isBusy)
    }

    private func referenceList(for mode: RealtimeExampleMode) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86, maximum: 100), spacing: 14)], spacing: 15) {
                uploadButton
                ForEach(controller.uploadedReferences.filter { $0.mode == mode } + mode.presets) { reference in
                    RealtimeReferenceButton(
                        reference: reference, isSelected: controller.selectedReferenceID == reference.id
                    ) {
                        Task { await controller.selectReference(reference) }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .disabled(!controller.canGenerate)
        .opacity(controller.hasAPIKey ? 1 : 0.45)
        .overlay(alignment: .bottom) {
            if !controller.hasAPIKey {
                Text("本地预览中；结束会话并填写 API Key 后可体验生成。")
                    .font(.system(size: 11))
                    .foregroundStyle(RealtimePalette.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.95), in: Capsule())
            }
        }
    }

    private var uploadButton: some View {
        Button { presentImporter() } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle().fill(RealtimePalette.surface)
                    Circle().strokeBorder(RealtimePalette.border, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    if let progress = controller.uploadProgress {
                        ProgressView(value: progress).progressViewStyle(.circular).controlSize(.small)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 23, weight: .light))
                            .foregroundStyle(RealtimePalette.secondary)
                    }
                }
                .frame(width: 66, height: 66)
                Text("Upload").font(.system(size: 10)).foregroundStyle(RealtimePalette.secondary)
            }
            .frame(width: 86)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("上传自己的参考图")
        .accessibilityLabel("上传参考图")
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if controller.prompt.isEmpty {
                    Text("描述你希望画面如何变化…")
                        .foregroundStyle(RealtimePalette.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $controller.prompt)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("生成描述")
            }
            .font(.system(size: 13))
            .frame(height: 94)
            HStack(spacing: 12) {
                if let reference = controller.freeReference {
                    RealtimeThumbnail(url: reference.thumbnailURL)
                        .frame(width: 35, height: 35)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Text(reference.name).font(.system(size: 11)).lineLimit(1)
                    Button { controller.removeFreeReference() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .help("移除参考图")
                        .disabled(controller.isBusy)
                } else {
                    Button { presentImporter() } label: { Label("参考图", systemImage: "photo.badge.plus") }
                        .buttonStyle(RealtimeActionButtonStyle())
                        .disabled(!controller.canGenerate)
                }
                Spacer()
                if controller.isBusy { ProgressView().controlSize(.small) }
                Text("⌘ ↵").font(.system(size: 11)).foregroundStyle(RealtimePalette.secondary)
                Button { Task { await controller.submitPrompt() } } label: {
                    Label("生成", systemImage: "arrow.up")
                }
                .buttonStyle(RealtimeActionButtonStyle(appearance: .primary))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!controller.canGenerate)
            }
        }
        .padding(17)
        .background(RealtimePalette.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RealtimePalette.border))
        .frame(maxWidth: 860)
    }

    /// 记录上传所属模式，不使用异步返回时的当前页签。
    private func presentImporter() {
        uploadMode = controller.activeMode
        importPresented = true
    }
}
