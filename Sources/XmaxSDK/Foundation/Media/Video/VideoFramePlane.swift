//
//  VideoFramePlane.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// A pixel data plane in a video frame.
struct VideoFramePlane: Equatable, Sendable {

    /// Pixel storage
    let data: Data

    /// Plane layout
    let stride: Int
    let byteOffset: Int
    let byteLength: Int

    /// Creates a video pixel plane referencing a valid byte range.
    ///
    /// - Parameters:
    ///   - data: The nonempty data retaining pixel bytes.
    ///   - stride: The row byte stride; must be positive.
    ///   - byteOffset: The plane's starting byte offset in the buffer.
    ///   - byteLength: The valid plane byte count; `nil` uses all data after the offset.
    /// - Throws: A configuration error for empty data, out-of-bounds ranges, or invalid row stride.
    init(
        data: Data,
        stride: Int,
        byteOffset: Int = 0,
        byteLength: Int? = nil
    ) throws {
        guard !data.isEmpty,
              byteOffset >= 0,
              byteOffset < data.count else {
            throw Self.invalidRangeError
        }

        let resolvedByteLength = byteLength ?? data.count - byteOffset
        guard resolvedByteLength > 0,
              resolvedByteLength <= data.count - byteOffset else {
            throw Self.invalidRangeError
        }
        guard stride > 0 else {
            throw XmaxError(
                code: .invalidConfiguration,
                message: "Video frame plane stride must be a positive integer"
            )
        }

        self.data = data
        self.stride = stride
        self.byteOffset = byteOffset
        self.byteLength = resolvedByteLength
    }

    /// Range validation errors
    private static var invalidRangeError: XmaxError {
        XmaxError(
            code: .invalidConfiguration,
            message: "Video frame plane range is invalid"
        )
    }
}
