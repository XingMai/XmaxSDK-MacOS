# Installation guide

Start with the [README installation steps](../README.md#installation). This guide
covers the native macOS package and its dependencies.

## Requirements

- macOS 13.0 or later
- Xcode 26 or later with Swift 6.2+; Swift 6 language mode
- Apple silicon (`arm64`) or Intel (`x86_64`)

## Swift Package Manager

In Xcode, add the repository through **File → Add Package Dependencies** and select
a branch or published version containing the SDK:

```text
https://github.com/XingMai/XmaxSDK-MacOS.git
```

Add only the **XmaxSDK** product to your application target. For a local checkout,
choose **Add Local** and select the SDK directory instead. A package manifest can
use `.package(path: "/path/to/XmaxSDK")`.

- Agora RTC `4.6.2` resolves from the
  [official macOS package](https://github.com/AgoraIO/AgoraRtcEngine_macOS), using
  the `RtcBasic` product.
- COS `6.5.7` is packaged as Xmax-built dynamic XCFrameworks for
  `QCloudCore/WithoutMTA` and `QCloudCOSXML/Transfer`, downloaded from the
  [COS dependency release](https://github.com/XingMai/XmaxSDK-MacOS/releases/tag/cos-6.5.7-spm.1).
  `Package.swift` pins each archive URL and SHA-256 checksum. These are macOS
  binaries, separate from the iOS frameworks.
- Both COS frameworks contain native macOS `arm64` and `x86_64` slices. Xcode
  handles linking, embedding, and signing the dynamic dependencies.
- Keep the bundled licenses, notices, resources, and privacy manifests when
  redistributing the frameworks. See the
  [redistribution notices](../Resources/COS/COS-6.5.7-NOTICES.txt).

The frameworks are built from Tencent's [unmodified 6.5.7 source](https://github.com/tencentyun/qcloud-sdk-ios/tree/6.5.7),
without optional analytics components. This is Xmax's binary packaging, not an
official Tencent Swift package. The source repository does not need to contain
the COS binaries; SwiftPM downloads and verifies the archives during dependency
resolution, following the same distribution approach as the iOS SDK.

## CocoaPods

Follow the [Podfile example](../README.md#cocoapods), then run:

```bash
pod install --repo-update
```

Open the generated `.xcworkspace`. CocoaPods builds the same `Sources/XmaxSDK`
using official Agora `4.6.2` and COS `6.5.7` dependencies; it does not link the
SwiftPM Release assets. The SDK pod includes `XmaxSDK_COS.bundle` to retain
the COS privacy manifest.

Use one package manager for the SDK and its dependencies in an application target.
Do not add the same frameworks separately through SwiftPM, CocoaPods, or manual
embedding.

## Configure the application target

Add `NSCameraUsageDescription` to your application's `Info.plist` for built-in
camera capture. Add `NSMicrophoneUsageDescription` if enabling microphone input.
The usage descriptions must describe your application's behavior.

For App Sandbox, enable **Camera**, **Outgoing Connections (Client)**, and
**Audio Input** when using a microphone. Ensure your network configuration also
permits RTC traffic; [XLab's entitlements](../Examples/XLab/XLab/XLab.entitlements)
show the example application's configuration. Configure the corresponding
resource permissions for Hardened Runtime.

If the application reads a user-selected reference image, use the appropriate
sandbox file access capability and retain access for the duration of the upload.
External video sources own their capture permissions and device lifecycle.

## Example application

Open [`Examples/XLab/XLab.xcodeproj`](../Examples/XLab/XLab.xcodeproj), select
**XLab**, and run on your Mac. It uses the local Swift package and adds Kingfisher
as an example-only dependency. Kingfisher is not required by SDK consumers.

Continue with the [Quick Start](../README.md#quick-start) or the
[usage guide](./usage.md).
