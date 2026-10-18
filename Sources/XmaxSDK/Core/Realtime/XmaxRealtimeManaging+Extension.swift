import Foundation

/// 提供常用默认参数，简化摄像头流创建与生成调用。
public extension XmaxRealtimeManaging {

    /// 使用指定视频规格创建不使用麦克风的摄像头流。
    ///
    /// - Parameters:
    ///   - videoFormat: 模型支持的摄像头输出规格。
    ///   - deviceID: 设备标识；为空时使用系统默认摄像头。
    /// - Returns: 包含本地摄像头轨道的媒体流。
    /// - Throws: 权限、设备配置或采集启动失败时抛出错误。
    func createLocalCameraStream(
        videoFormat: RealtimeVideoFormat,
        deviceID: String? = nil
    ) async throws -> RealtimeMediaStream {
        try await createLocalCameraStream(
            videoFormat: videoFormat,
            deviceID: deviceID,
            useMicrophone: false
        )
    }

    /// 使用当前模型的默认横向规格创建本地摄像头流。
    ///
    /// - Parameters:
    ///   - deviceID: 设备标识；为空时使用系统默认摄像头。
    ///   - useMicrophone: 是否使用麦克风，默认关闭。
    /// - Returns: 包含本地摄像头轨道的媒体流。
    /// - Throws: 权限、设备配置或采集启动失败时抛出错误。
    func createLocalCameraStream(
        deviceID: String? = nil,
        useMicrophone: Bool = false
    ) async throws -> RealtimeMediaStream {
        try await createLocalCameraStream(
            videoFormat: options.model.defaultCameraVideoFormat,
            deviceID: deviceID,
            useMicrophone: useMicrophone
        )
    }

    /// 使用已缓存的生成条件开始或更新生成。
    ///
    /// 首次开始生成时没有缓存条件，因此仍需调用带 `context` 参数的重载。
    ///
    /// - Parameter faceRestoration: 是否回贴原始人脸，默认关闭。
    /// - Throws: 没有可复用条件，或生成启动及更新失败时抛出错误。
    func startGeneration(faceRestoration: Bool = false) async throws {
        try await startGeneration(context: nil, faceRestoration: faceRestoration)
    }

    /// 开始或更新生成，默认关闭人脸还原。
    ///
    /// - Parameter context: 本次生成条件；传入 `nil` 时复用缓存条件。
    /// - Throws: 条件无效或生成启动、更新失败时抛出错误。
    func startGeneration(context: RealtimeContext?) async throws {
        try await startGeneration(context: context, faceRestoration: false)
    }

    /// 使用当前本地流按需连接并开始生成，默认关闭人脸还原。
    ///
    /// - Parameters:
    ///   - localStream: 当前 Manager 创建并持有的本地媒体流。
    ///   - context: 本次生成条件；首次生成不能为空。
    /// - Returns: 当前连接对应的远端媒体流。
    /// - Throws: 本地流无效、连接失败或生成启动失败时抛出错误。
    func startGeneration(
        localStream: RealtimeMediaStream,
        context: RealtimeContext?
    ) async throws -> RealtimeMediaStream {
        try await startGeneration(
            localStream: localStream,
            context: context,
            faceRestoration: false
        )
    }

    /// 使用当前本地流和已缓存条件按需连接并开始生成。
    ///
    /// 首次开始生成时没有缓存条件，因此仍需调用带 `context` 参数的重载。
    ///
    /// - Parameters:
    ///   - localStream: 当前 Manager 创建并持有的本地媒体流。
    ///   - faceRestoration: 是否回贴原始人脸，默认关闭。
    /// - Returns: 当前 RTC 连接对应的远端媒体流。
    /// - Throws: 没有可复用条件、本地流无效，或连接及生成启动失败时抛出错误。
    func startGeneration(
        localStream: RealtimeMediaStream,
        faceRestoration: Bool = false
    ) async throws -> RealtimeMediaStream {
        try await startGeneration(
            localStream: localStream,
            context: nil,
            faceRestoration: faceRestoration
        )
    }
}
