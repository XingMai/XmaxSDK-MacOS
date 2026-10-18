//
//  AudioFrame.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// A 48 kHz mono PCM frame for the RTC external audio pipeline.
struct AudioFrame: Equatable, Sendable {

    /// Audio format
    static let sampleRate = 48_000
    static let channelCount = 1
    static let samplesPerFrame = 480

    /// Frame data
    let data: Data
    let timestampUs: Int64
}
