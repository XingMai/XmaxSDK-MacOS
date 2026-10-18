//
//  CameraPosition.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// The lens position used for camera capture.
public enum CameraPosition: String, CaseIterable, Sendable {
    case front
    case back
    case unspecified
}
