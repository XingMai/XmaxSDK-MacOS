//
//  MediaServicing+Generation.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

public extension MediaServicing {
    /// Selects the closest generation canvas aspect ratio without changing local media format.
    ///
    /// - Parameter size: The media display dimensions.
    /// - Returns: The closest model resolution bucket or dimensions meeting model area and alignment constraints.
    /// - Throws: An error if media dimensions are invalid.
    func resolveGenerationSize(_ size: CGSize) throws -> CGSize {
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else {
            throw XmaxError(code: .invalidConfiguration, message: "Media dimensions must be positive")
        }

        let aspect = size.width / size.height
        if let bucket = model.resolutionBuckets.min(by: {
            abs(log(aspect / ($0.width / $0.height))) < abs(log(aspect / ($1.width / $1.height)))
        }) {
            return bucket
        }

        let size = try validatedSize(size)
        let pixels = Double(size.width) * Double(size.height)
        let scale: Double
        let rounding: (Double) -> Double

        if pixels < Double(model.minimumInputPixels) {
            scale = sqrt(Double(model.minimumInputPixels) / pixels)
            rounding = ceil
        } else if pixels > Double(model.maximumInputPixels) {
            scale = sqrt(Double(model.maximumInputPixels) / pixels)
            rounding = floor
        } else {
            scale = 1
            rounding = round
        }

        let alignment = Double(model.inputSizeAlignment)
        let width = max(
            Int(rounding(Double(size.width) * scale / alignment)) *
                model.inputSizeAlignment,
            model.inputSizeAlignment
        )
        let height = max(
            Int(rounding(Double(size.height) * scale / alignment)) *
                model.inputSizeAlignment,
            model.inputSizeAlignment
        )
        let alignedPixels = width * height
        if (model.minimumInputPixels...model.maximumInputPixels).contains(alignedPixels) {
            return CGSize(width: width, height: height)
        }

        // Alignment can cross size boundaries; selects the closest dimensions satisfying area limits.
        return boundedAlignedSize(
            width: Double(size.width) * scale,
            height: Double(size.height) * scale
        )
    }
}

private extension MediaServicing {
    /// Selects dimensions closest to the target while satisfying model area and alignment constraints.
    ///
    /// - Parameters:
    ///   - width: The scaled target width in pixels.
    ///   - height: The scaled target height in pixels.
    /// - Returns: The valid candidate minimizing relative width and height deviation.
    func boundedAlignedSize(width: Double, height: Double) -> CGSize {
        let alignment = model.inputSizeAlignment
        let unitPixels = alignment * alignment
        let minimumUnits = (model.minimumInputPixels + unitPixels - 1) / unitPixels
        let maximumUnits = model.maximumInputPixels / unitPixels
        var bestSize = CGSize.zero
        var bestDistance = Double.infinity

        for widthUnits in 1...maximumUnits {
            let minimumHeight = (minimumUnits + widthUnits - 1) / widthUnits
            let maximumHeight = maximumUnits / widthUnits
            guard minimumHeight <= maximumHeight else { continue }
            let heightUnits = min(
                max(Int((height / Double(alignment)).rounded()), minimumHeight),
                maximumHeight
            )
            let candidateWidth = Double(widthUnits * alignment)
            let candidateHeight = Double(heightUnits * alignment)
            let distance = pow((candidateWidth - width) / width, 2)
                + pow((candidateHeight - height) / height, 2)
            if distance < bestDistance {
                bestDistance = distance
                bestSize = CGSize(width: candidateWidth, height: candidateHeight)
            }
        }
        return bestSize
    }

    /// Validates media dimensions and rounds them to at least one pixel.
    ///
    /// - Parameter size: The media dimensions to validate.
    /// - Returns: Media dimensions with positive integer width and height.
    /// - Throws: A configuration error for nonfinite, nonpositive, or out-of-integer-range dimensions.
    func validatedSize(_ size: CGSize) throws -> CGSize {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0,
              size.width < CGFloat(Int.max),
              size.height < CGFloat(Int.max) else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Image width and height must be finite numbers " +
                    "greater than zero"
            )
        }
        return CGSize(
            width: max(size.width.rounded(), 1),
            height: max(size.height.rounded(), 1)
        )
    }
}
