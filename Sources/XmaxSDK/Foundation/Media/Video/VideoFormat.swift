//
//  VideoFormat.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// Fixed video frame dimensions and pixel format.
struct VideoFormat: Equatable, Sendable {

    /// Frame format
    let width: Int
    let height: Int
    let pixelFormat: VideoPixelFormat

    /// Creates a pixel format with valid dimensions.
    ///
    /// - Parameters:
    ///   - width: The frame width in pixels; must be positive.
    ///   - height: The frame height in pixels; must be positive.
    ///   - pixelFormat: The frame data pixel format.
    /// - Throws: A configuration error for nonpositive width or height.
    init(
        width: Int,
        height: Int,
        pixelFormat: VideoPixelFormat
    ) throws {
        guard width > 0, height > 0 else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Video width and height must be positive integers"
            )
        }

        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
    }
}
