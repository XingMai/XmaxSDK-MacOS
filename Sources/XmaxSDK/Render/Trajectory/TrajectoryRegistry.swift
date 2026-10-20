//
//  TrajectoryRegistry.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Registers interaction separately from video rendering, keyed by track object identity.
@MainActor
enum TrajectoryRegistry {
    private static var bindings: [ObjectIdentifier: TrajectoryBinding] = [:]

    static func register(_ track: RealtimeVideoTrack, binding: TrajectoryBinding) {
        unregister(track)
        bindings[ObjectIdentifier(track)] = binding
    }

    static func binding(for track: RealtimeVideoTrack) -> TrajectoryBinding? {
        bindings[ObjectIdentifier(track)]
    }

    static func unregister(_ track: RealtimeVideoTrack) {
        bindings.removeValue(forKey: ObjectIdentifier(track))?.invalidate()
    }
}
