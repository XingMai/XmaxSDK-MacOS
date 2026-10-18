//
//  RealtimeLaunchTiming.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭 (Yueting Weng)
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

/// 实时生成启动耗时快照，与 iOS 性能日志使用相同的四阶段口径，单位为毫秒。
///
/// 未执行或尚未完成的阶段为 `nil`。总耗时从生成启动调用进入业务流程开始，
/// 到首帧就绪并完成生成状态提交结束，不包含摄像头准备或额外渲染等待。
/// 总耗时包含阶段间的业务编排，因此不必等于四项耗时之和。
public struct RealtimeLaunchTiming: Equatable, Sendable {

    /// 创建服务端会话的耗时。
    public let sessionMs: Double?

    /// 调用 RTC 进房到进房成功的耗时。
    public let rtcJoinMs: Double?

    /// 发布本地媒体流的耗时。
    public let publishMs: Double?

    /// 提交生成信令到第一张可显示结果帧就绪的耗时。
    public let firstFrameMs: Double?

    /// 本次生成启动流程的完整耗时。
    public let totalMs: Double?

    /// 创建启动耗时快照，未完成的阶段保持 `nil`。
    ///
    /// - Parameters:
    ///   - sessionMs: 会话创建耗时，单位为毫秒。
    ///   - rtcJoinMs: RTC 进房耗时，单位为毫秒。
    ///   - publishMs: 本地流发布耗时，单位为毫秒。
    ///   - firstFrameMs: 生成信令到首帧就绪耗时，单位为毫秒。
    ///   - totalMs: 完整生成启动耗时，单位为毫秒。
    public init(
        sessionMs: Double? = nil,
        rtcJoinMs: Double? = nil,
        publishMs: Double? = nil,
        firstFrameMs: Double? = nil,
        totalMs: Double? = nil
    ) {
        self.sessionMs = sessionMs
        self.rtcJoinMs = rtcJoinMs
        self.publishMs = publishMs
        self.firstFrameMs = firstFrameMs
        self.totalMs = totalMs
    }
}

/// 主线程启动耗时回调；新一次生成启动时收到空快照，随后随阶段完成更新。
public typealias RealtimeLaunchTimingListener = @MainActor @Sendable (RealtimeLaunchTiming) -> Void
