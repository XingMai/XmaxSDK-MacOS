//
//  RoomEvent.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: Yueting Weng
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Creates structured event messages exchanged between the SDK and RTC room.
enum RoomEvent {
    /// Encodes a generation start signal with runtime environment information.
    ///
    /// - Parameters:
    ///   - userID: The local RTC user account.
    ///   - taskID: The current generation task identifier.
    ///   - videoFormat: The server generation video format.
    ///   - targetSize: The returned pixel dimensions; `nil` preserves generation dimensions.
    ///   - context: The current generation conditions.
    ///   - faceRestoration: Whether to restore the original face.
    ///   - paddingContain: Whether to preserve source aspect ratio and pad the generation canvas.
    /// - Returns: The sendable JSON start signal.
    /// - Throws: An error on invalid generation parameters, bitrate calculation failure, or JSON encoding failure.
    static func start(
        userID: String,
        taskID: String,
        videoFormat: RealtimeVideoFormat,
        targetSize: CGSize? = nil,
        context: RealtimeContext,
        faceRestoration: Bool = false,
        paddingContain: Bool = false
    ) throws -> String {
        try encode(
            StartPayload(
                params: GenerationParameters(
                    videoFormat: videoFormat,
                    targetSize: targetSize,
                    context: context,
                    faceRestoration: faceRestoration,
                    paddingContain: paddingContain,
                    mirror: false
                ),
                userID: userID,
                taskID: taskID
            )
        )
    }

    /// Encodes generation condition updates with runtime environment information.
    ///
    /// - Parameters:
    ///   - userID: The local RTC user account.
    ///   - taskID: The current generation task identifier.
    ///   - videoFormat: The server generation video format.
    ///   - targetSize: The returned pixel dimensions; `nil` preserves generation dimensions.
    ///   - context: The current generation conditions.
    ///   - faceRestoration: Whether to restore the original face.
    ///   - paddingContain: Whether to preserve source aspect ratio and pad the generation canvas.
    /// - Returns: The sendable JSON condition update signal.
    /// - Throws: An error on invalid generation parameters or JSON encoding failure.
    static func changeCondition(
        userID: String,
        taskID: String,
        videoFormat: RealtimeVideoFormat,
        targetSize: CGSize? = nil,
        context: RealtimeContext,
        faceRestoration: Bool = false,
        paddingContain: Bool = false
    ) throws -> String {
        try encode(
            ChangeConditionPayload(
                params: GenerationParameters(
                    videoFormat: videoFormat,
                    targetSize: targetSize,
                    context: context,
                    faceRestoration: faceRestoration,
                    paddingContain: paddingContain
                ),
                userID: userID,
                taskID: taskID
            )
        )
    }

    /// Encodes return dimension and downstream bitrate updates.
    ///
    /// - Parameters:
    ///   - userID: The local RTC user account.
    ///   - taskID: The generation task identifier to update.
    ///   - targetSize: The returned integer-pixel dimensions.
    /// - Returns: The sendable JSON return dimension update signal.
    /// - Throws: An error on invalid target dimensions, bitrate calculation failure, or JSON encoding failure.
    static func changeTargetSize(
        userID: String,
        taskID: String,
        targetSize: CGSize
    ) throws -> String {
        try encode(
            ChangeTargetSizePayload(
                params: TargetSizeParameters(size: targetSize),
                userID: userID,
                taskID: taskID
            )
        )
    }

    /// Encodes a generation stop signal.
    ///
    /// - Parameters:
    ///   - userID: The local RTC user account.
    ///   - taskID: The generation task identifier to stop.
    /// - Returns: The sendable JSON stop signal.
    /// - Throws: An error if JSON encoding fails.
    static func stop(
        userID: String,
        taskID: String
    ) throws -> String {
        try encode(
            StopPayload(
                userID: userID,
                taskID: taskID
            )
        )
    }

    /// Encodes a generation task's media-normalized trajectory.
    ///
    /// - Parameters:
    ///   - userID: The local RTC user account.
    ///   - taskID: The generation task receiving the trajectory.
    ///   - points: Points in sample order, normalized to `[0, 1]` relative to processed media dimensions.
    /// - Returns: The sendable JSON trajectory signal.
    /// - Throws: An error on invalid coordinates or JSON encoding failure.
    static func tracks(
        userID: String,
        taskID: String,
        points: [RealtimePoint]
    ) throws -> String {
        try encode(
            TracksPayload(
                tracks: points.map { [$0.x, $0.y] },
                userID: userID,
                taskID: taskID
            )
        )
    }

    /// Encodes a room heartbeat signal.
    ///
    /// - Parameter userID: The local RTC user account.
    /// - Returns: The sendable JSON heartbeat signal.
    /// - Throws: An error if JSON encoding fails.
    static func heartbeat(userID: String) throws -> String {
        try encode(HeartbeatPayload(userID: userID))
    }
}

private extension RoomEvent {
    /// Validates return dimensions and calculates downstream bitrate budget.
    ///
    /// - Parameter size: The return video integer-pixel dimensions.
    /// - Returns: The downstream minimum and maximum bitrate in kbps.
    /// - Throws: An error on invalid dimensions or bitrate calculation failure.
    static func downlinkBitrates(_ size: CGSize) throws -> (minimum: Int, maximum: Int) {
        guard size.width.isFinite, size.height.isFinite,
              size.width >= 2, size.height >= 2,
              size.width < CGFloat(Int.max), size.height < CGFloat(Int.max),
              size.width.rounded(.down) == size.width,
              size.height.rounded(.down) == size.height else {
            throw XmaxError(code: .invalidConfiguration, message: "Invalid return video dimensions")
        }
        let budget = try EncodingBitratePolicy.resolve(RealtimeVideoFormat(
            width: Int(size.width), height: Int(size.height), fps: 24
        ))
        return (100, min(10000, budget.maximum))
    }

    /// Adds runtime environment and session task fields, then encodes the signal.
    ///
    /// - Parameter payload: The encodable business event payload.
    /// - Returns: The UTF-8 JSON text with stable key ordering.
    /// - Throws: An error on payload encoding, JSON conversion, or text conversion failure.
    static func encode(_ payload: some Encodable) throws -> String {
        let payloadData = try JSONEncoder().encode(
            Envelope(payload: payload, runtime: .current)
        )
        guard var object = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw XmaxError(code: .internalError, message: "Failed to encode RTC room event")
        }
        if let taskID = object["uid"] {
            object["session_uid"] = taskID
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let message = String(data: data, encoding: .utf8) else {
            throw XmaxError(
                code: .internalError,
                message: "Failed to encode RTC room event"
            )
        }
        return message
    }

    /// Adds runtime environment information to business signals.
    struct Envelope<Payload: Encodable>: Encodable {

        /// Signal content
        let payload: Payload

        /// Runtime environment
        let runtime: RuntimeInfo

        /// Writes the business payload and runtime environment into one encoding container.
        ///
        /// - Parameter encoder: The encoder emitting the signal.
        /// - Throws: An error if payload or runtime environment encoding fails.
        func encode(to encoder: Encoder) throws {
            try payload.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(runtime, forKey: .runtime)
        }

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case runtime
        }
    }

    /// Encodes generation dimensions, reference conditions, and output options.
    struct GenerationParameters: Encodable {

        /// Generation model and dimensions
        let model = "default"
        let size: [Int]
        let targetSize: [Int]?

        /// Generation conditions
        let prompt: String
        let referencePath: String?

        /// Video processing
        let mirror: Bool?
        let faceRestoration: Bool
        let padding: String?

        /// Downstream bitrate
        let minimumBitrate: Int?
        let maximumBitrate: Int?

        /// Creates generation parameters, optionally including downstream bitrate configuration.
        ///
        /// - Parameters:
        ///   - videoFormat: The server generation video format.
        ///   - targetSize: The return dimensions; `nil` preserves generation dimensions.
        ///   - context: The generation conditions, including reference images and prompt.
        ///   - faceRestoration: Whether to restore the original face.
        ///   - paddingContain: Whether to fit content within the canvas using padding.
        ///   - mirror: The optional mirror setting; a non-nil value also adds downstream bitrate fields.
        /// - Throws: An error on invalid dimensions or bitrate when downstream bitrate calculation is required.
        init(
            videoFormat: RealtimeVideoFormat,
            targetSize: CGSize?,
            context: RealtimeContext,
            faceRestoration: Bool,
            paddingContain: Bool = false,
            mirror: Bool? = nil
        ) throws {
            size = [videoFormat.width, videoFormat.height]
            self.targetSize = targetSize.map { [Int($0.width), Int($0.height)] }
            prompt = context.prompt
            referencePath = context.referencePath
            self.mirror = mirror
            self.faceRestoration = faceRestoration
            padding = paddingContain ? "contain" : nil
            if mirror != nil {
                let budget = try RoomEvent.downlinkBitrates(targetSize ?? videoFormat.size)
                minimumBitrate = budget.minimum
                maximumBitrate = budget.maximum
            } else {
                minimumBitrate = nil
                maximumBitrate = nil
            }
        }

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case model
            case size
            case targetSize = "target_size"
            case prompt
            case referencePath = "ref_image_path"
            case mirror
            case faceRestoration = "face_replace"
            case padding
            case minimumBitrate = "min_bitrate"
            case maximumBitrate = "max_bitrate"
        }
    }

    /// A room signal starting generation.
    struct StartPayload: Encodable {

        /// Event type
        let event = "start"

        /// Event parameters
        let params: GenerationParameters

        /// User and task identifiers
        let userID: String
        let taskID: String

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case event
            case params
            case userID = "user_id"
            case taskID = "uid"
        }
    }

    /// A room signal updating generation conditions.
    struct ChangeConditionPayload: Encodable {

        /// Event type
        let event = "change_condition"

        /// Event parameters
        let params: GenerationParameters

        /// User and task identifiers
        let userID: String
        let taskID: String

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case event
            case params
            case userID = "user_id"
            case taskID = "uid"
        }
    }

    /// Encodes return dimensions and the associated downstream bitrate budget.
    struct TargetSizeParameters: Encodable {

        /// Return dimensions
        let targetSize: [Int]

        /// Downstream bitrate
        let minimumBitrate: Int
        let maximumBitrate: Int

        /// Validates and creates return dimension and bitrate parameters.
        ///
        /// - Parameter size: The target return dimensions in integer pixels.
        /// - Throws: An error on dimension validation or downstream bitrate calculation failure.
        init(size: CGSize) throws {
            let budget = try RoomEvent.downlinkBitrates(size)
            targetSize = [Int(size.width), Int(size.height)]
            minimumBitrate = budget.minimum
            maximumBitrate = budget.maximum
        }

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case targetSize = "target_size"
            case minimumBitrate = "min_bitrate"
            case maximumBitrate = "max_bitrate"
        }
    }

    /// A room signal dynamically adjusting return dimensions.
    struct ChangeTargetSizePayload: Encodable {

        /// Event type
        let event = "change_target_size"

        /// Event parameters
        let params: TargetSizeParameters

        /// User and task identifiers
        let userID: String
        let taskID: String

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case event
            case params
            case userID = "user_id"
            case taskID = "uid"
        }
    }

    /// A room signal stopping generation.
    struct StopPayload: Encodable {

        /// Event type
        let event = "stop"

        /// User and task identifiers
        let userID: String
        let taskID: String

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case event
            case userID = "user_id"
            case taskID = "uid"
        }
    }

    /// A room signal carrying a generation task's media-normalized trajectory.
    struct TracksPayload: Encodable {

        /// Event type
        let event = "tracks"

        /// Trajectory data
        let tracks: [[Double]]

        /// User and task identifiers
        let userID: String
        let taskID: String

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case event
            case tracks
            case userID = "user_id"
            case taskID = "uid"
        }
    }

    /// A heartbeat signal keeping the room active.
    struct HeartbeatPayload: Encodable {

        /// Event type
        let event = "heartbeat"

        /// User and task identifiers
        let userID: String

        /// Maps field names defined by the server signaling protocol.
        enum CodingKeys: String, CodingKey {
            case event
            case userID = "user_id"
        }
    }
}
