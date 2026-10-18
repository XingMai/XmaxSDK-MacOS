//
//  PermissionManaging.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Defines permission checks and requests required by the SDK.
protocol PermissionManaging: Sendable {

    /// Ensures camera access, requesting system permission if not yet determined.
    ///
    /// - Throws: A camera permission error if access is denied, restricted, or authorization fails.
    func ensureCameraPermission() async throws

    /// Ensures microphone access, requesting system permission if not yet determined.
    ///
    /// - Throws: A microphone permission error if access is denied, restricted, or authorization fails.
    func ensureMicrophonePermission() async throws
}
