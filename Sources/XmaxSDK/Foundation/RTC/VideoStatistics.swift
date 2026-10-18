//
//  VideoStatistics.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// RTC upstream video statistics; unavailable metrics are nil.
public struct UplinkVideoStatistics: Equatable, Sendable {

    /// The actual encoding width in pixels.
    public let width: Int?

    /// The actual encoding height in pixels.
    public let height: Int?

    /// The actual capture frame rate in fps.
    public let captureFrameRate: Int?

    /// The actual encoding frame rate in fps.
    public let encodeFrameRate: Int?

    /// The actual sending frame rate in fps.
    public let sendFrameRate: Int?

    /// The sending bitrate in kbps.
    public let bitrateKbps: Int?

    /// The local-to-RTC packet loss percentage in 0...100.
    public let packetLossPercent: Int?

    /// Creates video statistics.
    ///
    /// - Parameters:
    ///   - width: The actual encoding width in pixels; nil when unavailable.
    ///   - height: The actual encoding height in pixels; nil when unavailable.
    ///   - captureFrameRate: The actual capture frame rate in fps; nil when unavailable.
    ///   - encodeFrameRate: The actual encoding frame rate in fps; nil when unavailable.
    ///   - sendFrameRate: The actual sending frame rate in fps; nil when unavailable.
    ///   - bitrateKbps: The sending bitrate in kbps; nil when unavailable.
    ///   - packetLossPercent: The local-to-RTC packet loss percentage in 0...100; nil when unavailable.
    public init(
        width: Int? = nil,
        height: Int? = nil,
        captureFrameRate: Int? = nil,
        encodeFrameRate: Int? = nil,
        sendFrameRate: Int? = nil,
        bitrateKbps: Int? = nil,
        packetLossPercent: Int? = nil
    ) {
        self.width = width
        self.height = height
        self.captureFrameRate = captureFrameRate
        self.encodeFrameRate = encodeFrameRate
        self.sendFrameRate = sendFrameRate
        self.bitrateKbps = bitrateKbps
        self.packetLossPercent = packetLossPercent
    }
}

/// RTC downstream video statistics; unavailable metrics are nil.
public struct DownlinkVideoStatistics: Equatable, Sendable {

    /// The remote user identifier.
    public let userID: String

    /// The received video width in pixels.
    public let width: Int?

    /// The received video height in pixels.
    public let height: Int?

    /// The decoding frame rate in fps.
    public let decodeFrameRate: Int?

    /// The RTC rendering frame rate in fps, excluding SDK interpolation.
    public let renderFrameRate: Int?

    /// The receiving bitrate in kbps.
    public let bitrateKbps: Int?

    /// The downstream video packet loss percentage in 0...100.
    public let packetLossPercent: Int?

    /// The RTC media end-to-end latency in milliseconds, excluding full AI generation time.
    public let endToEndDelayMs: Int?

    /// Creates video statistics.
    ///
    /// - Parameters:
    ///   - userID: The remote user identifier.
    ///   - width: The received video width in pixels; nil when unavailable.
    ///   - height: The received video height in pixels; nil when unavailable.
    ///   - decodeFrameRate: The decoding frame rate in fps; nil when unavailable.
    ///   - renderFrameRate: The RTC rendering frame rate in fps, excluding SDK interpolation; nil when unavailable.
    ///   - bitrateKbps: The receiving bitrate in kbps; nil when unavailable.
    ///   - packetLossPercent: The downstream video packet loss percentage in 0...100; nil when unavailable.
    ///   - endToEndDelayMs: The RTC media end-to-end latency in milliseconds, excluding full AI generation time; nil when unavailable.
    public init(
        userID: String,
        width: Int? = nil,
        height: Int? = nil,
        decodeFrameRate: Int? = nil,
        renderFrameRate: Int? = nil,
        bitrateKbps: Int? = nil,
        packetLossPercent: Int? = nil,
        endToEndDelayMs: Int? = nil
    ) {
        self.userID = userID
        self.width = width
        self.height = height
        self.decodeFrameRate = decodeFrameRate
        self.renderFrameRate = renderFrameRate
        self.bitrateKbps = bitrateKbps
        self.packetLossPercent = packetLossPercent
        self.endToEndDelayMs = endToEndDelayMs
    }
}

/// Main-thread upstream video statistics callback; receives nil after publication stops or disconnect.
public typealias UplinkVideoStatisticsListener = @MainActor @Sendable (UplinkVideoStatistics?) -> Void

/// Main-thread downstream video statistics callback; receives nil after result cleanup or disconnect.
public typealias DownlinkVideoStatisticsListener = @MainActor @Sendable (DownlinkVideoStatistics?) -> Void
