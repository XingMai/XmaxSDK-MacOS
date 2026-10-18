# macOS framework archive

此目录为本地 CD 提供可随版本标签恢复的 CocoaPods 归档输入。它不集成到 XLab 应用；XLab 继续通过 SwiftPM 接入 SDK。

准备版本时更新 `Podfile.lock` 并提交。验证和发布时使用 `pod install --deployment --no-repo-update`，然后对生成的 `Pods.xcodeproj` 的 `XmaxSDK` scheme 进行原生 macOS 双架构归档。

发行包包含静态 `XmaxSDK.xcframework`。手动接入时还需链接、嵌入和签名固定版本的 Agora 与 COS 动态依赖，保留依赖自带的许可证和隐私清单。
