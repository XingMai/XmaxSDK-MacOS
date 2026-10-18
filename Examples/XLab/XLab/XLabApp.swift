//
//  XLabApp.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import SwiftUI
import XmaxSDK

/// Native macOS camera and realtime generation example.
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
