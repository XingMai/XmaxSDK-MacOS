//
//  RealtimeConfiguration.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Business configuration for creating a realtime manager.
public struct RealtimeConfiguration: Equatable, Sendable {

    /// The model used for realtime generation.
    public let model: RealtimeModel

    /// Whether interpolation of generated remote video is enabled by default.
    public let isFrameInterpolationEnabled: Bool

    /// Creates realtime business configuration.
    ///
    /// - Parameters:
    ///   - model: The model used for realtime generation.
    ///   - isFrameInterpolationEnabled: Whether interpolation of generated remote video is enabled by default.
    public init(
        model: RealtimeModel,
        isFrameInterpolationEnabled: Bool = false
    ) {
        self.model = model
        self.isFrameInterpolationEnabled = isFrameInterpolationEnabled
    }
}
