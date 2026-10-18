//
//  XLabApp.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI
import XmaxSDK

/// 原生 macOS 摄像头与实时生成示例。
@main
struct XLabApp: App {
    var body: some Scene {
        WindowGroup {
            RealtimeView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .defaultSize(width: 1360, height: 850)
    }
}
