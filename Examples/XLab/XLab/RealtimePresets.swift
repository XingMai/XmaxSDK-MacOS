//
//  RealtimePresets.swift
//  XLab
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Uses the same generation modes and preset reference assets as Web X-Lab.
enum RealtimeExampleMode: String, CaseIterable, Identifiable, Sendable {
    case charx, clothx, vibex, free

    var id: String { rawValue }

    var title: String {
        switch self {
        case .charx: "Character Swap"
        case .clothx: "Virtual Try-On"
        case .vibex: "Style Transfer"
        case .free: "Free Prompt"
        }
    }

    var prompt: String {
        switch self {
        case .charx: "视频中角色替换成参考图中角色"
        case .clothx: "视频中人物衣服替换成参考图中衣服"
        case .vibex: "视频风格变为参考图指定的风格"
        case .free: ""
        }
    }

    var faceRestoration: Bool { self == .clothx }

    var presets: [RealtimeReference] {
        switch self {
        case .charx:
            [
                .preset(.charx, version: "20260909", name: "Classical Girl", image: "charx_image1.jpeg", reference: "charx_real_image1.png"),
                .preset(.charx, version: "20260909", name: "Classical Boy", image: "charx_image2.jpeg", reference: "charx_real_image2.png"),
                .preset(.charx, version: "20260909", name: "Modern Girl", image: "charx_image3.png", reference: "charx_real_image3.png"),
                .preset(.charx, version: "20260909", name: "Modern Boy", image: "charx_image4.png", reference: "charx_real_image4.png"),
                .preset(.charx, version: "20260909", name: "Blonde Girl", image: "charx_image5.png", reference: "charx_real_image5.png"),
                .preset(.charx, version: "20260909", name: "Curly-Haired Boy", image: "charx_image6.png", reference: "charx_real_image6.jpeg"),
                .preset(.charx, version: "20260909", name: "Anime Boy", image: "charx_image7.png", reference: "charx_real_image7.png"),
                .preset(.charx, version: "20260909", name: "Anime Girl", image: "charx_image8.png", reference: "charx_real_image8.png"),
                .preset(.charx, version: "20260909", name: "Alien Kitty", image: "charx_image9.jpeg", reference: "charx_real_image9.png"),
                .preset(.charx, version: "20260909", name: "Bronze Figure", image: "charx_image10.png", reference: "charx_real_image10.jpeg"),
                .preset(.charx, version: "20260909", name: "3D Cow", image: "charx_image11.png", reference: "charx_real_image11.png"),
                .preset(.charx, version: "20260909", name: "3D Milk Frog", image: "charx_image12.png", reference: "charx_real_image12.jpeg"),
                .preset(.charx, version: "20260909", name: "3D Kangaroo", image: "charx_image13.jpg", reference: "charx_real_image13.jpeg"),
                .preset(.charx, version: "20260909", name: "Mecha Girl", image: "charx_image14.png", reference: "charx_real_image14.png"),
                .preset(.charx, version: "20260909", name: "Mecha Warrior", image: "charx_image15.jpg", reference: "charx_real_image15.png"),
                .preset(.charx, version: "20260909", name: "Special Ops", image: "charx_image16.jpeg", reference: "charx_real_image16.png"),
                .preset(.charx, version: "20260909", name: "Humanoid Robot", image: "charx_image17.png", reference: "charx_real_image17.jpg"),
                .preset(.charx, version: "20260909", name: "Chill Capybara", image: "charx_image18.jpeg", reference: "charx_real_image18.jpg"),
                .preset(.charx, version: "20260909", name: "Gentle Panda", image: "charx_image19.png", reference: "charx_real_image19.png"),
                .preset(.charx, version: "20260909", name: "Cute Hamster", image: "charx_image20.png", reference: "charx_real_image20.jpg"),
                .preset(.charx, version: "20260909", name: "Illustrated Girl", image: "charx_image21.png", reference: "charx_real_image21.png"),
                .preset(.charx, version: "20260909", name: "Cartoon Boy", image: "charx_image22.jpeg", reference: "charx_real_image22.jpeg"),
                .preset(.charx, version: "20260909", name: "Business Milk Frog", image: "charx_image23.png", reference: "charx_real_image23.png"),
                .preset(.charx, version: "20260909", name: "Corporate Cow", image: "charx_image24.jpeg", reference: "charx_real_image24.jpeg"),
            ]
        case .clothx:
            [
                .preset(.clothx, version: "20260909", name: "Gilded Goddess", image: "clothx_image1.png", reference: "clothx_real_image1.jpg"),
                .preset(.clothx, version: "20260909", name: "Monochrome Vanguard", image: "clothx_image2.png", reference: "clothx_real_image2.png"),
                .preset(.clothx, version: "20260909", name: "Silver Fantasy Robe", image: "clothx_image3.png", reference: "clothx_real_image3.jpeg"),
                .preset(.clothx, version: "20260909", name: "Navy Sailor Outfit", image: "clothx_image4.png", reference: "clothx_real_image4.png"),
                .preset(.clothx, version: "20260909", name: "Long Coat Set", image: "clothx_image5.png", reference: "clothx_real_image5.png"),
                .preset(.clothx, version: "20260909", name: "Pink Academy", image: "clothx_image6.png", reference: "clothx_real_image6.jpeg"),
                .preset(.clothx, version: "20260909", name: "Bronze Warrior Armor", image: "clothx_image7.png", reference: "clothx_real_image7.png"),
                .preset(.clothx, version: "20260909", name: "Vintage Brown", image: "clothx_image8.png", reference: "clothx_real_image8.png"),
                .preset(.clothx, version: "20260909", name: "Black-Collar Academy", image: "clothx_image9.png", reference: "clothx_real_image9.jpeg"),
                .preset(.clothx, version: "20260909", name: "Blue Plaid Academy", image: "clothx_image10.png", reference: "clothx_real_image10.jpeg"),
                .preset(.clothx, version: "20260909", name: "Black Pinafore", image: "clothx_image11.png", reference: "clothx_real_image11.jpeg"),
                .preset(.clothx, version: "20260909", name: "Coffee Cardigan", image: "clothx_image12.png", reference: "clothx_real_image12.jpeg"),
                .preset(.clothx, version: "20260909", name: "Lilac Slip Dress", image: "clothx_image13.png", reference: "clothx_real_image13.jpeg"),
                .preset(.clothx, version: "20260909", name: "Magenta Techwear", image: "clothx_image14.png", reference: "clothx_real_image14.png"),
                .preset(.clothx, version: "20260909", name: "Luxury Suit", image: "clothx_image15.png", reference: "clothx_real_image15.png"),
                .preset(.clothx, version: "20260909", name: "Navy Officewear", image: "clothx_image16.png", reference: "clothx_real_image16.png"),
                .preset(.clothx, version: "20260909", name: "Burgundy Stripes", image: "clothx_image17.png", reference: "clothx_real_image17.jpeg"),
                .preset(.clothx, version: "20260909", name: "Light Blue Sportswear", image: "clothx_image18.png", reference: "clothx_real_image18.png"),
                .preset(.clothx, version: "20260909", name: "Silver Casualwear", image: "clothx_image19.png", reference: "clothx_real_image19.png"),
                .preset(.clothx, version: "20260909", name: "British Brown Plaid", image: "clothx_image20.png", reference: "clothx_real_image20.png"),
                .preset(.clothx, version: "20260909", name: "Blue and White Retro", image: "clothx_image21.png", reference: "clothx_real_image21.jpeg"),
                .preset(.clothx, version: "20260909", name: "All-Denim Outfit", image: "clothx_image22.png", reference: "clothx_real_image22.png"),
                .preset(.clothx, version: "20260909", name: "Gray Eveningwear", image: "clothx_image23.png", reference: "clothx_real_image23.png"),
                .preset(.clothx, version: "20260909", name: "Black Classical Robe", image: "clothx_image24.png", reference: "clothx_real_image24.png"),
            ]
        case .vibex:
            [
                .preset(.vibex, version: "20260911", name: "American Cartoon", image: "vibex_image1.jpg", reference: "vibex_real_image1.png"),
                .preset(.vibex, version: "20260911", name: "3D Cartoon", image: "vibex_image2.jpg", reference: "vibex_real_image2.png"),
                .preset(.vibex, version: "20260911", name: "School Anime", image: "vibex_image3.jpg", reference: "vibex_real_image3.png"),
                .preset(.vibex, version: "20260911", name: "Urban Anime", image: "vibex_image4.jpg", reference: "vibex_real_image4.png"),
                .preset(.vibex, version: "20260911", name: "Japanese Anime", image: "vibex_image5.jpg", reference: "vibex_real_image5.png"),
                .preset(.vibex, version: "20260911", name: "Realistic Animals", image: "vibex_image9.png", reference: "vibex_real_image9.png"),
                .preset(.vibex, version: "20260911", name: "Designer Toy", image: "vibex_image10.png", reference: "vibex_real_image10.png"),
                .preset(.vibex, version: "20260911", name: "Anthropomorphic", image: "vibex_image15.jpeg", reference: "vibex_real_image15.png"),
                .preset(.vibex, version: "20260911", name: "Surrealism", image: "vibex_image17.png", reference: "vibex_real_image17.png"),
                .preset(.vibex, version: "20260911", name: "Disney Style", image: "vibex_image18.png", reference: "vibex_real_image18.png"),
                .preset(.vibex, version: "20260911", name: "Cel Shading", image: "vibex_image19.png", reference: "vibex_real_image19.png"),
                .preset(.vibex, version: "20260911", name: "Japanese Animation", image: "vibex_image21.png", reference: "vibex_real_image21.png"),
            ]
        case .free: []
        }
    }
}

/// Presets and uploaded reference images share the selection and generation flow.
struct RealtimeReference: Identifiable, Sendable {
    let id: String
    let mode: RealtimeExampleMode
    let name: String
    let thumbnailURL: URL
    var referencePath: String
    var thumbnailData: Data? = nil
    var prompt: String? = nil
    var uploadState: UploadState = .ready
    var uploadProgress: Double = 0
    var uploadError: String? = nil

    enum UploadState: Sendable { case ready, uploading, error }

    /// COS serves 160px WebP thumbnails; generation still uses the original Web reference URLs.
    static func preset(
        _ mode: RealtimeExampleMode,
        version: String,
        name: String,
        image: String,
        reference: String
    ) -> Self {
        let base = "https://cdn.22duck.cn/images/source/\(mode.rawValue)"
        let thumbnail = "\(base)/\(image)?presetVersion=\(version)&imageMogr2/thumbnail/160x160/format/webp/quality/80"
        let path = "\(base)/\(reference)?presetVersion=\(version)"
        return Self(id: path, mode: mode, name: name, thumbnailURL: URL(string: thumbnail)!, referencePath: path)
    }
}
