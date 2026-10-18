//
//  QualityVideoFormat.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Calculates transport tiers from the media baseline without changing capture or model generation format.
enum QualityVideoFormat {

    /// Tier configuration
    static let scales: [Double] = [1, 0.8, 0.65, 0.5, 0.5]
    static let frameRates = [30, 24, 24, 20, 16]

    /// Calculates downstream dimension limits without pixel alignment or interpolation limits.
    ///
    /// - Parameters:
    ///   - baseline: The original media format, unchanged by tier adjustments.
    ///   - level: The target downstream tier in 1...5.
    /// - Returns: Dimension limits preserving aspect ratio, potentially with fractional pixels.
    static func resolveDownlinkMaximumSize(_ baseline: RealtimeVideoFormat, level: Int) -> CGSize {
        let scale = sizeScale(baseline, level: level)
        return CGSize(width: Double(baseline.width) * scale, height: Double(baseline.height) * scale)
    }

    /// Calculates transport format for a direction and tier from the baseline.
    ///
    /// - Parameters:
    ///   - baseline: The original local media format.
    ///   - level: The target tier, clamped to `1...5`.
    ///   - downlink: Whether downstream; uses 24 fps downstream and at most the baseline frame rate upstream.
    /// - Returns: The transport format with dimensions, frame rate, and encoding options mapped.
    static func resolve(_ baseline: RealtimeVideoFormat, level: Int, downlink: Bool) -> RealtimeVideoFormat {
        let index = min(5, max(1, level)) - 1
        let scale = sizeScale(baseline, level: level)
        let size = scaledSize(baseline.size, scale: scale)
        return RealtimeVideoFormat(
            width: Int(size.width), height: Int(size.height),
            fps: downlink ? 24 : min(baseline.fps, frameRates[index]),
            minimumBitrate: downlink ? nil : baseline.minimumBitrate,
            maximumBitrate: downlink ? nil : baseline.maximumBitrate,
            encoderPreference: baseline.encoderPreference
        )
    }

    /// Scales dimensions down, preferring exact aspect ratio and even alignment.
    ///
    /// - Parameters:
    ///   - size: The original integer-pixel dimensions.
    ///   - scale: The target dimension scale factor.
    /// - Returns: Even-aligned dimensions, rounding down to pixel precision when exact aspect ratio cannot be preserved.
    static func scaledSize(_ size: CGSize, scale: Double) -> CGSize {
        let width = Int(size.width)
        let height = Int(size.height)
        var divisor = width
        var remainder = height
        while remainder != 0 { (divisor, remainder) = (remainder, divisor % remainder) }
        let units = Int(floor(Double(divisor) * scale + 0.0000001)) / 2 * 2
        if units >= 2 {
            return CGSize(width: width / divisor * units, height: height / divisor * units)
        }
        return CGSize(
            width: max(2, Int(floor(Double(width) * scale / 2)) * 2),
            height: max(2, Int(floor(Double(height) * scale / 2)) * 2)
        )
    }

    /// Calculates tier scaling while preserving the minimum short side and avoiding upscaling.
    ///
    /// - Parameters:
    ///   - baseline: The original media format.
    ///   - level: The target tier in 1...5.
    /// - Returns: A dimension scale factor at most 1.
    private static func sizeScale(_ baseline: RealtimeVideoFormat, level: Int) -> Double {
        let index = min(5, max(1, level)) - 1
        let shortSide = min(baseline.width, baseline.height)
        return max(scales[index], Double(min(shortSide, 240)) / Double(shortSide))
    }
}
