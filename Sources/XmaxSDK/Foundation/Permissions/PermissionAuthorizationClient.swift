//
//  PermissionAuthorizationClient.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

@preconcurrency import AVFoundation

/// Media permissions checked by the SDK.
enum MediaPermission: Equatable, Sendable {
    case camera
    case microphone
}

/// Neutral authorization states for platform media permissions.
enum MediaAuthorizationStatus: Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

/// Provides platform media permission queries and asynchronous authorization.
struct PermissionAuthorizationClient: Sendable {

    /// Authorization interface
    let authorizationStatus: @Sendable (
        _ permission: MediaPermission
    ) -> MediaAuthorizationStatus
    let requestAccess: @Sendable (
        _ permission: MediaPermission
    ) async throws -> Bool

    /// Platform implementation
    static let live = PermissionAuthorizationClient(
        authorizationStatus: { permission in
            let status = AVCaptureDevice.authorizationStatus(
                for: permission.mediaType
            )
            switch status {
            case .notDetermined:
                return .notDetermined
            case .restricted:
                return .restricted
            case .denied:
                return .denied
            case .authorized:
                return .authorized
            @unknown default:
                return .denied
            }
        },
        requestAccess: { permission in
            await AVCaptureDevice.requestAccess(for: permission.mediaType)
        }
    )
}

private extension MediaPermission {

    /// System media types
    var mediaType: AVMediaType {
        switch self {
        case .camera:
            return .video
        case .microphone:
            return .audio
        }
    }
}
