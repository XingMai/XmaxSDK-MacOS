# COS macOS SwiftPM binaries

`QCloudCore.xcframework` 与 `QCloudCOSXML.xcframework` 由 Xmax 从腾讯云官方 `tencentyun/qcloud-sdk-ios` 的 `6.5.7` 源码构建，分别对应 `QCloudCore/WithoutMTA` 与 `QCloudCOSXML/Transfer`。这是 Xmax 的 macOS 二进制包装，不是腾讯云官方 Swift Package。

- 平台：原生 macOS，最低系统 macOS 13.0。
- 架构：arm64、x86_64，合并为同一 macOS 变体。
- 链接：动态框架，保留 Objective-C category；接入方由 Xcode 自动嵌入与签名。
- 不包含腾讯统计和设备标识上报可选组件。
- 源码：https://github.com/tencentyun/qcloud-sdk-ios/tree/6.5.7
- 官方模块与版本由 `.cicd/consumer/COSBinary/Podfile.lock` 固定。
- 框架 Resources 内包含上游许可证、第三方声明及已有的隐私清单。Redistribution 时须保留。

本目录的二进制是 SwiftPM 包内容的一部分，应随仓库分发。CocoaPods 使用官方源码依赖，不链接本目录中的二进制。重建脚本将产物保存到 `.build/COSSwiftPM/artifacts`，不会覆盖本目录；更换前应重新验证两种消费端。

详见 `COS-6.5.7-NOTICES.txt`。
