//
//  MediaService.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import CoreGraphics

/// Provides business rules for local media, return dimensions, and platform media capabilities.
final class MediaService: MediaServicing, Sendable {

    /// Model constraints
    let model: RealtimeModel

    /// Interpolation constraints
    private static let maximumFrameInterpolationPixels = 900000

    /// Creates a media service using the specified model dimension rules.
    ///
    /// - Parameter model: The generation model used to resolve input dimensions.
    init(model: RealtimeModel = .x2_1_1_preview_cn) {
        self.model = model
    }

    /// Calculates local frame dimensions and validates camera and external video resolution buckets.
    ///
    /// - Parameters:
    ///   - size: Requested camera dimensions or oriented integer-pixel image or video dimensions.
    ///   - source: The media source; camera and external video inputs must match configured resolution buckets.
    /// - Returns: Dimensions aligned to four pixels without upscaling or exceeding model area limits, preferring exact aspect ratio.
    /// - Throws: An error on invalid dimensions, unmatched input resolution buckets, or no valid output dimensions.
    func resolveMediaSize(_ size: CGSize, source: RealtimeMediaSource) throws -> CGSize {
        guard let width = Self.integralDimension(size.width),
              let height = Self.integralDimension(size.height) else {
            throw XmaxError(code: .invalidConfiguration, message: "Media dimensions must be positive integers")
        }

        let buckets = model.resolutionBuckets
        if source == .camera || source == .external, !buckets.isEmpty, !buckets.contains(size) {
            let supportedSizes = buckets.map { "\(Int($0.width))×\(Int($0.height))" }.joined(separator: ", ")
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Model \(model.rawValue) does not support \(source.rawValue) resolution " +
                    "\(width)×\(height). Supported resolutions: \(supportedSizes)"
            )
        }

        let pixels = Double(width) * Double(height)
        let scale = min(1, sqrt(Double(model.maximumInputPixels) / pixels))
        return try alignedSize(width: width, height: height, scale: scale, alignment: 4)
    }

    /// Calculates final return dimensions from tier limits and optional interpolation constraints.
    ///
    /// - Parameters:
    ///   - sourceSize: The original integer-pixel media dimensions defining aspect ratio and no-upscaling bounds.
    ///   - maximumSize: The downstream tier dimension limits, potentially containing fractional pixels.
    ///   - frameInterpolationEnabled: Whether to additionally limit total pixels to 900000; does not check device capabilities.
    /// - Returns: Dimensions within limits and aligned to four pixels; prefers exact aspect ratio, otherwise rounds each side down.
    /// - Throws: `XmaxError` for invalid dimensions or limits that cannot accommodate at least 4 × 4 pixels.
    func resolveTargetSize(
        _ sourceSize: CGSize,
        maximumSize: CGSize,
        frameInterpolationEnabled: Bool
    ) throws -> CGSize {
        guard let width = Self.integralDimension(sourceSize.width),
              let height = Self.integralDimension(sourceSize.height),
              maximumSize.width.isFinite, maximumSize.width > 0,
              maximumSize.height.isFinite, maximumSize.height > 0 else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Source dimensions must be positive integers and target bounds must be positive and finite"
            )
        }

        var scale = min(1, min(Double(maximumSize.width) / Double(width), Double(maximumSize.height) / Double(height)))
        let targetPixels = (Double(width) * scale) * (Double(height) * scale)
        if frameInterpolationEnabled, targetPixels > Double(Self.maximumFrameInterpolationPixels) {
            scale *= sqrt(Double(Self.maximumFrameInterpolationPixels) / targetPixels)
        }

        return try alignedSize(width: width, height: height, scale: scale, alignment: 4)
    }

    /// Checks device interpolation support for the specified video resolution.
    ///
    /// - Parameter size: The received video resolution used for interpolation.
    /// - Returns: `true` if the system, device, and video format all support interpolation.
    func supportsFrameInterpolation(for size: CGSize) -> Bool {
        guard Self.supportsFrameInterpolationSize(size) else {
            return false
        }
        return FrameInterpolationSupport.supports(size: size)
    }

    /// Checks positive integer dimensions and the interpolation pixel area limit.
    ///
    /// - Parameter size: The video dimensions to check, in pixels.
    /// - Returns: `true` for valid dimensions within the pixel area limit; does not check device capabilities.
    static func supportsFrameInterpolationSize(_ size: CGSize) -> Bool {
        guard let width = integralDimension(size.width),
              let height = integralDimension(size.height) else {
            return false
        }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(
            by: height
        )
        return !overflow && pixelCount <= maximumFrameInterpolationPixels
    }
}

private extension MediaService {
    /// Calculates aligned dimensions within scaling limits, preferring multiples of the reduced aspect ratio.
    ///
    /// - Parameters:
    ///   - width: The original integer-pixel width.
    ///   - height: The original integer-pixel height.
    ///   - scale: The proportional scale factor, at most 1.
    ///   - alignment: The required pixel alignment multiple for both dimensions.
    /// - Returns: Aligned dimensions within scaling bounds, rounding each side down if exact aspect ratio is impossible.
    /// - Throws: An error if the scaling bounds cannot accommodate one alignment unit.
    func alignedSize(width: Int, height: Int, scale: Double, alignment: Int) throws -> CGSize {
        // Uses multiples of the reduced aspect ratio to avoid distortion from independent rounding.
        var divisor = width
        var remainder = height
        while remainder != 0 {
            (divisor, remainder) = (remainder, divisor % remainder)
        }
        let ratioWidth = width / divisor
        let ratioHeight = height / divisor
        let alignedScale = Int(floor(Double(divisor) * scale / Double(alignment))) * alignment
        if alignedScale >= alignment {
            return CGSize(
                width: ratioWidth * alignedScale,
                height: ratioHeight * alignedScale
            )
        }

        let alignedWidth = Int(floor(Double(width) * scale / Double(alignment))) * alignment
        let alignedHeight = Int(floor(Double(height) * scale / Double(alignment))) * alignment
        guard alignedWidth >= alignment, alignedHeight >= alignment else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "No aligned video size is available within the size limits"
            )
        }
        return CGSize(width: alignedWidth, height: alignedHeight)
    }

    /// Converts a valid positive integer pixel dimension to an integer.
    ///
    /// - Parameter value: The pixel dimension to validate.
    /// - Returns: A safely convertible positive integer; `nil` for nonfinite, fractional, or out-of-range values.
    static func integralDimension(_ value: CGFloat) -> Int? {
        guard value.isFinite,
              value > 0,
              value < CGFloat(Int.max) else {
            return nil
        }
        let roundedValue = value.rounded()
        guard roundedValue == value else { return nil }
        return Int(roundedValue)
    }
}
