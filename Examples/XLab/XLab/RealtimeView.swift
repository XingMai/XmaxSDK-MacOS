//
//  RealtimeView.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Kingfisher
import SwiftUI
import UniformTypeIdentifiers
import XmaxSDK

/// 对齐 Web X-Lab 的启动页、顶栏设置和双屏会话布局。
struct RealtimeView: View {
    @Environment(\.displayScale) private var displayScale
    @StateObject private var controller = RealtimeSessionController()
    @State private var keyEditorOpen = false
    @State private var modelPickerOpen = false
    @State private var wechatOpen = false
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if controller.sessionActive {
                        Spacer(minLength: 0)
                        header(viewportWidth: geometry.size.width)
                        RealtimeSessionWorkspace(controller: controller)
                        Spacer(minLength: 0)
                    } else {
                        header(viewportWidth: geometry.size.width)
                        Spacer(minLength: 30)
                        landingPage(viewportWidth: geometry.size.width)
                        Spacer(minLength: 30)
                        footer
                    }
                }
                .modifier(RealtimePageEntry())
                .id(controller.sessionActive)
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 48)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background {
            // SDK 要求预览先绑定才能进入 ready；启动页持续显示 loading，连接成功后才显示双屏。
            if !controller.sessionActive, let stream = controller.localStream {
                XmaxVideo(track: stream.videoTrack)
                    .frame(width: 1, height: 1)
                    .opacity(0)
                    .accessibilityHidden(true)
            }
        }
        .background(.white)
        .font(RealtimeHeaderTypography.font(size: 13))
        .foregroundStyle(RealtimePalette.text)
        .preferredColorScheme(.light)
        .tint(RealtimePalette.accent)
        .overlay(alignment: .top) {
            if let message = controller.errorMessage {
                errorToast(message).padding(.top, 84)
            }
        }
        .task(id: controller.errorMessage) {
            guard controller.errorMessage != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            controller.dismissError()
        }
        .onDisappear { controller.viewDidDisappear() }
    }

    /// 品牌与会话设置
    private func header(viewportWidth: CGFloat) -> some View {
        let controlHeight = min(48, max(35, viewportWidth * 0.0055 + 26))
        let logoHeight = min(52, max(34, viewportWidth * 0.008 + 24))
        return HStack(spacing: 12) {
            Image("XmaxWordmark")
                .resizable().scaledToFit()
                .frame(width: logoHeight * 552 / 172, height: logoHeight)
                .accessibilityLabel("Xmax")
            Spacer()
            if controller.sessionActive {
                RealtimeSessionHeaderControls(controller: controller)
            } else {
                modelPicker(height: controlHeight)
                keyButton(height: controlHeight)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func modelPicker(height: CGFloat) -> some View {
        Button { modelPickerOpen.toggle() } label: {
            Text(controller.model.displayName)
                .padding(.leading, 18)
                .padding(.trailing, 30)
                .overlay(alignment: .trailing) {
                    RealtimeHeaderChevron()
                        .foregroundStyle(RealtimePalette.secondary)
                        .padding(.trailing, 14)
                }
        }
        .buttonStyle(RealtimeHeaderButtonStyle(height: height, horizontalPadding: 0))
        .fixedSize()
        .disabled(controller.isBusy)
        .accessibilityLabel("Model")
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

    private func keyButton(height: CGFloat) -> some View {
        Button { keyEditorOpen.toggle() } label: {
            HStack(spacing: 8) {
                RealtimeKeyIcon()
                if controller.hasAPIKey {
                    Text(controller.apiKey).lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: 270)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(RealtimeHeaderButtonStyle(
            height: height, iconOnly: !controller.hasAPIKey, muted: !controller.hasAPIKey
        ))
        .fixedSize(horizontal: true, vertical: false)
        .help("API Key")
        .accessibilityLabel("API Key")
        .popover(isPresented: $keyEditorOpen, arrowEdge: .bottom) {
            TextField("API Key", text: $controller.apiKey)
                .textFieldStyle(.plain)
                .font(RealtimeHeaderTypography.font(size: 13))
                .padding(.vertical, 8).padding(.horizontal, 12)
                .background(RealtimePalette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                    keyFieldFocused ? RealtimePalette.accent : RealtimePalette.border
                ))
                .focused($keyFieldFocused)
                .onSubmit { keyEditorOpen = false }
                .onExitCommand { keyEditorOpen = false }
                .accessibilityLabel("API Key")
                .padding(10)
                .frame(width: 280)
                .onAppear { keyFieldFocused = true }
        }
    }

    /// 启动页沿用 Web 的尺寸公式、麦克风开关和单一启动入口。
    private func landingPage(viewportWidth: CGFloat) -> some View {
        let fontSize = min(45, max(27, viewportWidth * 0.01 + 18))
        let smallSize = min(15, max(12, viewportWidth * 0.0028 + 9.5))
        return VStack(spacing: 0) {
            Text("Reimagining Live Video with Xmax")
                .font(RealtimeHeaderTypography.font(size: fontSize, weight: .medium))
                .tracking(-fontSize * 0.03)
                .padding(.bottom, min(40, max(26, viewportWidth * 0.011 + 17)))
            ZStack {
                RealtimeCheckerboard()
                VStack(spacing: 20) {
                    RealtimeStartButton(isLoading: controller.isBusy, viewportWidth: viewportWidth) {
                        Task { await controller.start() }
                    }
                    Button { controller.useMicrophone.toggle() } label: {
                        HStack(spacing: 8) {
                            RealtimeWebIcon(kind: .microphone).frame(width: 14, height: 14)
                            Text("Microphone")
                            Capsule().fill(controller.useMicrophone ? RealtimePalette.accent : .white.opacity(0.18))
                                .frame(width: 30, height: 18)
                                .overlay(alignment: .leading) {
                                    Circle().fill(.white).frame(width: 14, height: 14)
                                        .offset(x: controller.useMicrophone ? 14 : 2)
                                }
                        }
                        .font(RealtimeHeaderTypography.font(size: smallSize))
                        .foregroundStyle(.white.opacity(controller.useMicrophone ? 1 : 0.55))
                        .padding(.leading, 14).padding(.trailing, 7).padding(.vertical, 6)
                        .background(.black.opacity(0.28), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(controller.useMicrophone ? 0.3 : 0.16)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Microphone")
                    .accessibilityValue(controller.useMicrophone ? "On" : "Off")
                    .animation(.easeInOut(duration: 0.15), value: controller.useMicrophone)
                }
                VStack {
                    Spacer()
                    Text("By clicking Start, you agree to our [Terms of Use](https://platform.xmaxai.com/docs/resources/terms) and [Privacy Policy](https://platform.xmaxai.com/docs/resources/privacy).")
                        .font(RealtimeHeaderTypography.font(size: smallSize))
                        .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.686))
                        .tint(Color(red: 0.765, green: 0.776, blue: 0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.bottom, 30)
                }
            }
            .aspectRatio(1920.0 / 1024.0, contentMode: .fit)
            .frame(width: min(viewportWidth - 56, min(940, max(580, viewportWidth * 0.45))))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            Text("Copyright © 2026 XMAX.AI PTE.LTD. All rights reserved.")
                .font(RealtimeHeaderTypography.font(size: min(14, max(11.5, viewportWidth * 0.0028 + 9))))
                .foregroundStyle(RealtimePalette.secondary)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 24) {
            HStack(spacing: 18) {
                Button { wechatOpen.toggle() } label: { RealtimeWebIcon(kind: .wechat).frame(width: 20, height: 20) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("WeChat")
                    .popover(isPresented: $wechatOpen, arrowEdge: .top) {
                        VStack(spacing: 8) {
                            KFImage(URL(string: "https://assets.22duck.fun/image/wechatAccount.jpg"))
                                .placeholder { Color.white }
                                .downsampling(size: CGSize(width: 180, height: 180))
                                .scaleFactor(displayScale)
                                .backgroundDecode()
                                .cancelOnDisappear(true)
                                .resizable().scaledToFit()
                                .frame(width: 180, height: 180)
                            Text("Follow us on WeChat").font(RealtimeHeaderTypography.font(size: 12))
                        }.padding(14)
                    }
                Link(destination: URL(string: "https://x.com/XmaxAIOfficial")!) {
                    RealtimeWebIcon(kind: .socialX).frame(width: 18, height: 18)
                }.accessibilityLabel("X")
                Link(destination: URL(string: "https://www.xmaxai.com")!) {
                    RealtimeWebIcon(kind: .globe).frame(width: 20, height: 20)
                }.accessibilityLabel("Website")
            }
            Spacer()
            Link("Contact Us", destination: URL(string: "mailto:contact@xmax.ai")!)
            Link("API Platform", destination: URL(string: "https://platform.xmaxai.com")!)
        }
        .font(RealtimeHeaderTypography.font(size: 13))
        .foregroundStyle(RealtimePalette.secondary)
        .padding(.top, 56)
    }

    private func errorToast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(Color(red: 0.898, green: 0.282, blue: 0.302))
            Text(message).font(RealtimeHeaderTypography.font(size: 14)).textSelection(.enabled)
            Button { controller.dismissError() } label: {
                Image(systemName: "xmark").frame(width: 24, height: 24)
            }.buttonStyle(.plain).foregroundStyle(RealtimePalette.secondary).accessibilityLabel("Dismiss")
        }
        .padding(.vertical, 12).padding(.leading, 16).padding(.trailing, 14)
        .frame(maxWidth: 560)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RealtimePalette.text.opacity(0.08)))
        .shadow(color: RealtimePalette.text.opacity(0.14), radius: 16, y: 12)
        .padding(.horizontal, 28)
    }
}

/// 会话顶栏沿用 Web 的统计、远端音量、插帧、计时与停止按钮。
struct RealtimeSessionHeaderControls: View {
    @ObservedObject var controller: RealtimeSessionController
    @State private var volumeOpen = false

    var body: some View {
        HStack(spacing: 12) {
            RealtimeHeaderPill { Text(controller.model.displayName) }.accessibilityLabel("Current model")
            Button { controller.statisticsVisible.toggle() } label: {
                RealtimeWebIcon(kind: .statistics).frame(width: 18, height: 18)
            }
            .buttonStyle(RealtimeSessionToolStyle(active: controller.statisticsVisible, kind: .statistics))
            .help(controller.statisticsVisible ? "Hide statistics (collection and logging continue)" : "Show statistics")
            .accessibilityLabel("Show statistics")
            .accessibilityValue(controller.statisticsVisible ? "On" : "Off")
            Button { volumeOpen.toggle() } label: {
                RealtimeWebIcon(kind: controller.remoteAudioVolume == 0 ? .muted : controller.remoteAudioVolume > 0.5 ? .volume : .volumeLow).frame(width: 18, height: 18)
            }
            .buttonStyle(RealtimeSessionToolStyle(active: controller.remoteAudioVolume > 0))
            .help("Adjust remote playback volume")
            .accessibilityLabel("Remote volume")
            .accessibilityValue(controller.remoteAudioVolume == 0 ? "Muted" : "\(Int(controller.remoteAudioVolume * 100))%")
            .popover(isPresented: $volumeOpen, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Remote volume")
                        Spacer()
                        Text(controller.remoteAudioVolume == 0 ? "Muted" : "\(Int(controller.remoteAudioVolume * 100))%")
                            .foregroundStyle(RealtimePalette.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(controller.remoteAudioVolume) },
                        set: { value in Task { await controller.setRemoteAudioVolume(Float(value)) } }
                    ), in: 0...1, step: 0.01).accessibilityLabel("Remote volume")
                }
                .font(RealtimeHeaderTypography.font(size: 12)).padding(14).frame(width: 216)
                .onExitCommand { volumeOpen = false }
            }
            Button { Task { await controller.toggleInterpolation() } } label: {
                HStack(spacing: 3) {
                    RealtimeWebIcon(kind: .lightning).frame(width: 15, height: 15)
                    Text("2x")
                }
            }
            .buttonStyle(RealtimeSessionToolStyle(active: controller.interpolationEnabled, kind: .interpolation))
            .disabled(controller.isBusy)
            .accessibilityLabel("Frame interpolation")
            .accessibilityValue(controller.interpolationEnabled ? "On" : "Off")
            .help(controller.interpolationSwitching ? "Switching frame interpolation…" :
                    controller.interpolationEnabled ? "2× frame interpolation is on. Click to turn off" : "Frame interpolation is off. Click to turn on")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                RealtimeHeaderPill { Text(elapsed(at: context.date)).monospacedDigit() }
            }
            Button { Task { await controller.close() } } label: {
                HStack(spacing: 7) { Text("■"); Text("Stop Session") }
            }
            .buttonStyle(RealtimeHeaderButtonStyle(height: 36, horizontalPadding: 16, destructive: true))
            .disabled(controller.isBusy)
            .help("Stop Session")
        }
        .task {
            while !Task.isCancelled {
                await controller.refreshInterpolationState()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// 会话计时从生成连接成功开始，结束后归零。
    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(controller.sessionStartedAt ?? date)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// 双屏与分类列表保持挂载，切换模式时保留各自滚动位置。
struct RealtimeSessionWorkspace: View {
    @ObservedObject var controller: RealtimeSessionController
    @State private var importPresented = false
    @State private var uploadMode = RealtimeExampleMode.charx

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                RealtimeVideoPanel(title: "Local", track: controller.localStream?.videoTrack, placeholder: "",
                                   statistics: controller.statisticsVisible ? controller.localStatisticsPanels : [])
                RealtimeVideoPanel(
                    title: "Result", track: controller.remoteStream?.videoTrack,
                    placeholder: controller.state.connectionState == .generating && controller.remoteStream != nil ? "" :
                        [.connected, .generating].contains(controller.state.connectionState) ? "Generating…" : "Waiting for connection…",
                    showsWatermark: true,
                    statistics: controller.statisticsVisible ? controller.remoteStatisticsPanels : []
                )
            }
            modeTabs.padding(.top, 34).padding(.bottom, 28)
            ZStack(alignment: .top) {
                promptEditor.opacity(controller.activeMode == .free ? 1 : 0)
                    .allowsHitTesting(controller.activeMode == .free).accessibilityHidden(controller.activeMode != .free)
                    .disabled(controller.activeMode != .free)
                ForEach(RealtimeExampleMode.allCases.filter { $0 != .free }) { mode in
                    referenceList(for: mode)
                        .opacity(controller.activeMode == mode ? 1 : 0)
                        .allowsHitTesting(controller.activeMode == mode).accessibilityHidden(controller.activeMode != mode)
                        .disabled(controller.activeMode != mode)
                }
            }
            .frame(height: 190, alignment: .top)
        }
        .fileImporter(isPresented: $importPresented, allowedContentTypes: [.image]) { result in
            if case let .success(url) = result {
                let mode = uploadMode
                Task { await controller.uploadReference(at: url, mode: mode) }
            }
        }
    }

    private var modeTabs: some View {
        HStack(spacing: 2) {
            ForEach(RealtimeExampleMode.allCases) { mode in
                Button { controller.activeMode = mode } label: { Text(mode.title) }
                    .buttonStyle(RealtimeModeTabStyle(isSelected: controller.activeMode == mode))
                    .accessibilityAddTraits(controller.activeMode == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(red: 120.0 / 255, green: 120.0 / 255, blue: 128.0 / 255).opacity(0.1), in: Capsule())
        .disabled(controller.isBusy)
    }

    private func referenceList(for mode: RealtimeExampleMode) -> some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    RealtimeReferenceGrid {
                        uploadButton.id("upload")
                        ForEach(controller.uploadedReferences.filter { $0.mode == mode } + mode.presets) { reference in
                            RealtimeReferenceButton(reference: reference, isSelected: controller.selectedReferenceID == reference.id,
                                                    action: { Task { await controller.selectReference(reference) } },
                                                    loadsThumbnail: controller.activeMode == mode)
                            .disabled(reference.uploadState == .uploading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .onChange(of: controller.uploadedReferences.first { $0.mode == mode }?.id) { _ in
                    proxy.scrollTo("upload", anchor: .top)
                }
            }
        }
        .disabled(!controller.canGenerate)
        .opacity(controller.canGenerate ? 1 : 0.35)
    }

    private var uploadButton: some View {
        Button { presentImporter() } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color(red: 250.0 / 255, green: 251.0 / 255, blue: 252.0 / 255))
                    Circle().strokeBorder(Color(red: 203.0 / 255, green: 210.0 / 255, blue: 220.0 / 255),
                                          style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    Text("＋").font(RealtimeHeaderTypography.font(size: 24))
                }.frame(width: 64, height: 64)
                Text("Upload").font(RealtimeHeaderTypography.font(size: 11)).frame(height: 14)
            }.foregroundStyle(RealtimePalette.secondary).frame(width: 76)
        }
        .buttonStyle(RealtimeUnstyledButtonStyle())
        .help("Upload your own reference image")
        .accessibilityLabel("Upload reference image")
    }

    private var promptEditor: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $controller.prompt)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Describe how you want the video to change")
                if controller.prompt.isEmpty {
                    Text("Describe how you want the video to change")
                        .foregroundStyle(RealtimePalette.secondary).padding(.horizontal, 5).padding(.top, 1)
                        .allowsHitTesting(false)
                }
            }
            .font(RealtimeHeaderTypography.font(size: 15))
            .padding(.horizontal, 8).padding(.vertical, 6).frame(height: 84)
            HStack(spacing: 10) {
                Spacer()
                if let reference = controller.freeReference {
                    RealtimeReferenceThumbnail(reference: reference, loadsThumbnail: controller.activeMode == .free)
                        .frame(width: 44, height: 44)
                        .overlay(alignment: .topTrailing) {
                            Button { controller.removeFreeReference() } label: {
                                Text("×").font(RealtimeHeaderTypography.font(size: 14, weight: .medium))
                                    .foregroundStyle(.white).frame(width: 18, height: 18)
                                    .background(.black.opacity(0.72), in: Circle())
                            }
                            .buttonStyle(.plain).offset(x: 5, y: -5)
                            .help("Remove reference").accessibilityLabel("Remove reference").disabled(controller.isBusy)
                        }
                        .help(reference.uploadError ?? reference.name)
                } else {
                    Button { presentImporter() } label: { RealtimeWebIcon(kind: .plus).frame(width: 22, height: 22) }
                        .buttonStyle(RealtimePromptButtonStyle())
                        .help("Upload your own reference image").accessibilityLabel("Upload reference image")
                        .disabled(!controller.canGenerate)
                }
                Button { Task { await controller.submitPrompt() } } label: {
                    RealtimeWebIcon(kind: .arrow).frame(width: 20, height: 20)
                }
                .buttonStyle(RealtimePromptButtonStyle(primary: true))
                .accessibilityLabel("Submit prompt")
                .help(controller.hasAPIKey ? "" : "Generation requires an API Key")
                .disabled(!controller.canGenerate || controller.referenceUploading)
            }
        }
        .padding(12)
        .background(RealtimePalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RealtimePalette.border))
        .frame(maxWidth: 880).padding(.top, 4)
    }

    /// 记录上传所属模式，不使用异步返回时的当前页签。
    private func presentImporter() {
        uploadMode = controller.activeMode
        importPresented = true
    }
}
