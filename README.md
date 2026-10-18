# XmaxSDK for macOS

原生 macOS 实时生成 SDK。沿用 iOS SDK 的 Core、Service、Stream、Media、Render、Foundation 分层及 Swift 并发、依赖注入、统一错误和日志设计。

当前版本 `1.0.0` 优先支持摄像头视频输入：设备枚举与切换、NV12 采集、RTC 上行、生成条件更新、远端帧回调，以及 AppKit / SwiftUI 本地预览和结果显示。保留独立存储服务，可用于上传参考图；图片和文件视频作为本地输入、鼠标轨迹交互暂未开放。麦克风默认关闭；保留 iOS 的可选 RTC 麦克风链路。插帧默认关闭，其复用实现需 macOS 26 及支持的硬件。

## 环境要求

- macOS 13.0 或更高版本。
- Xcode 26+，Swift 6.2+ 工具链，Swift 6 语言模式。
- 提供 arm64 和 x86_64 依赖；Intel 运行需在对应硬件上验收。
- 真实生成需要有效的 Xmax API Key；本地预览不需要 API Key。

## Swift Package Manager

当前工程尚未发布到远程仓库。开发时在 Xcode 中选择 **File → Add Package Dependencies → Add Local**，选中本目录，并将 **XmaxSDK** 产品加入应用 target。

命令行包可以使用本地路径依赖：

```swift
.package(path: "/path/to/XmaxSDK")
```

SDK 从源码编译，Agora 使用官方 `AgoraRtcEngine_macOS` Swift Package 的 `RtcBasic 4.6.2`，COS 使用仓库内 `Vendor/` 下的 macOS 动态 XCFramework。将 SDK 发布到 Git 仓库时须包含这两个 XCFramework；接入方不需要 CocoaPods 或自行构建 COS。

Agora macOS 4.6.4 目前没有对应的 CocoaPods 发布规格，因此 SwiftPM 和 CocoaPods 统一固定到 4.6.2。COS 的两个模块统一固定为 6.5.7。

## CocoaPods

```ruby
source 'https://cdn.cocoapods.org/'
platform :osx, '13.0'
use_frameworks! :linkage => :static

target 'YourApp' do
  pod 'XmaxSDK', path: '/path/to/XmaxSDK'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

CocoaPods 使用与 SwiftPM 相同的 `Sources/XmaxSDK`，通过正式 Pod 获取 Agora 与 COS，并通过 `XmaxSDK_COS.bundle` 保留上游 COS 隐私清单。Podspec 中的远程仓库地址为拟发布地址，当前请使用本地 path 接入。不要在同一个应用 target 中重复通过 SwiftPM、CocoaPods 或手动方式添加同一依赖。

## 权限

应用的 Info.plist 需要 `NSCameraUsageDescription`；使用麦克风时再配置 `NSMicrophoneUsageDescription`。

启用 App Sandbox / Hardened Runtime 时，应为应用开启 Camera、网络及所需的 Audio Input 权限。XLab 已包含对应 entitlement 和用途说明，SDK 不代替宿主应用配置权限。

## 摄像头与生成

在 MainActor 上创建客户端与实时 Manager：

```swift
let client = XmaxClient(configuration: XmaxConfiguration(apiKey: apiKey))
let manager = client.createRealtimeManager(
    options: RealtimeConfiguration(model: .x2_1_1_preview_cn)
)
let devices = await manager.listCameraDevices()
let localStream = try await manager.createLocalCameraStream(deviceID: nil)
```

`nil` 选择系统默认设备；传入具体设备 ID 时，设备失效会返回错误，不自动切换到其他设备。默认输出为模型支持的 `1920 × 1024 @ 30fps`，实际采集格式由设备能力选择并转换为 NV12。

将返回的轨道交给 SwiftUI：

```swift
XmaxRealtimeVideo(
    localTrack: localStream.videoTrack,
    remoteTrack: remoteStream?.videoTrack,
    videoContentMode: .fit
)
```

也可使用 `XmaxVideoView` / `XmaxRealtimeVideoView` 直接接入 AppKit。沿用 iOS 就绪语义：有效帧已到达、预览已绑定后进入 `ready`。窗口缩放不改变上行规格或断开生成。

监听 `ready` 后开始生成，并将返回的远端轨道交给视频视图：

```swift
let remoteStream = try await manager.startGeneration(
    localStream: localStream,
    context: RealtimeContext(prompt: "让画面呈现电影质感")
)
```

生成中再次调用 `startGeneration(context:)` 更新条件。`RealtimeContext.referencePath` 接受已经上传的参考图路径，存储入口与 iOS 保持一致。

```swift
_ = try await manager.switchCamera(to: deviceID)
await manager.disconnect()  // 保留本地摄像头预览
await manager.close()       // 释放摄像头、会话和 RTC 引擎
```

移除视频视图只解除显示绑定。宿主应用应在对应业务生命周期结束时调用 `close()`。活动摄像头拔出后会报告媒体错误并清理当前生命周期，应用可重新枚举设备并启动预览。

SDK 的 HTTP 平台字段、运行信息和生成信令统一使用 `macos`。

## 示例与验证

打开 `Examples/XLab/XLab.xcodeproj`。示例通过本地 Swift Package 接入 SDK，采用与 Web X-Lab 一致的浅色启动页与会话页：顶栏设置模型和 API Key，舞台内可开关麦克风，点击 Start Camera 后启动默认摄像头并使用首个角色预设生成；连接成功后进入会话页。

会话中左侧为 Local 摄像头画面，右侧为 Result 生成结果，两路独立显示、不互相叠加。下方提供角色替换、虚拟试衣、风格迁移、自由输入四个模式，使用与 Web 相同的参考图资源；切换模式不自动生成，点击预设或上传参考图后才更新生成条件。自由输入通过箭头按钮提交；虚拟试衣开启原始人脸还原。上传条目立即显示本地缩略图，带独立进度与失败重试；切换分类保留滚动位置且取消旧选择的自动应用。Stop Session 立即返回启动页并在后台释放资源。API Key 与 Web 一致保存在本机应用设置中，更换凭证需先结束会话。

会话顶栏提供统计显隐、远端音量与 2× 插帧开关。统计默认显示，隐藏仅影响界面，不停止 SDK 指标采集。上下行分辨率、RTC 帧率、码率、丢包、网络质量与 RTC 端到端时延接入 SDK 的真实回调；启动耗时与 iOS 性能日志一致，展示创建会话、RTC 进房、发布本地流、首帧到达及完整启动耗时，不包含摄像头准备和额外渲染等待；总耗时包含阶段间编排，不必等于四项之和。尚未公开的 RTT 和播放缓冲延迟显示 `—`。示例不接入录制与下载。图片通过 Kingfisher 8.10.0 加载、降采样与缓存，依赖仅声明在 XLab 的 Xcode 工程中，不进入 SDK 的 SwiftPM 或 CocoaPods 依赖。预设列表通过 COS 下载时处理请求 160px、质量 80 的 WebP 缩略图，避免先下载原图再本地缩小；生成用的 `reference_path` 保留原图。

与 Web 尚有两项交互差异：结果画面的鼠标轨迹交互未接通；参考图列表支持原生滚轮和触控板滚动，尚未实现 Web 的按住拖动滚动。模型选择、API Key 编辑和文件选择使用 macOS 原生弹层。

```bash
swift test
bash .cicd/verify.sh
```

单元测试使用 Stub 和本地 URLProtocol，覆盖会话、RTC、生成、质量控制、设备选择、切换失败、预览就绪及清理。验证脚本还构建 SwiftPM XLab 和 CocoaPods 最小消费端，并检查 App 中的动态依赖与隐私清单。测试不会访问真实摄像头或调用真实生成服务。

COS 的构建来源、版本和许可证见 `Vendor/README.md`，重新打包见 `.cicd/build-cos-swiftpm.sh`。

## 分支管理

沿用 iOS 仓库流程：`main` 保存发布基线，`develop` 保存验证通过的集成基线，日常开发位于 `feature/yueting-v<version>`。首个版本分支为 `feature/yueting-v1.0.0`。

提交信息采用 Conventional Commits，例如 `feat:`、`fix:`、`refactor:`、`docs:` 和 `chore:`。版本分支完成验证后，使用 fast-forward 同步 `develop` 和 `main`，再在 `main` 创建不带 `v` 的版本标签；发布完成后从该提交创建下一个版本分支。

与 iOS 一样，`.cicd/` 是不提交的本地验证与发版工具目录。`Vendor/` 内的两个 COS XCFramework 是 SwiftPM 的直接依赖，需要纳入版本管理。

本地发版入口与 iOS 一致：`ci-prepare.sh <version>` 同步版本与锁文件，`ci-merge.sh` 验证后原子快进主分支，`cd-github-release.sh <version>` 从版本标签归档并发布，成功后创建下一 patch 版本分支。发布归档使用版本管理中的 `Configurations/FrameworkArchive/Podfile.lock`；macOS 的 arm64 / x86_64 位于同一个平台变体中。
