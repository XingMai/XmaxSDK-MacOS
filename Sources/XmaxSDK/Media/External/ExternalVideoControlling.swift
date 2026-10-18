//
//  ExternalVideoControlling.swift
//  XmaxSDK
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Manages external video bindings without owning capture resources.
protocol ExternalVideoControlling: Sendable {

    /// The active external video track, or nil when unbound.
    var currentTrack: RealtimeVideoTrack? { get }

    /// Creates an external stream using model-validated input dimensions.
    @MainActor
    func create(
        source: any RealtimeExternalVideoSource,
        videoFormat: RealtimeVideoFormat?
    ) async throws -> RealtimeMediaStream

    /// Invalidates frame delivery, removes preview bindings, and notifies the source.
    @MainActor
    func stop() async
}
