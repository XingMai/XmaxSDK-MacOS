//
//  RoomHeartbeat.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation

/// Sends periodic RTC room heartbeats while isolating stopped cycles.
final class RoomHeartbeat: @unchecked Sendable {

    /// Foundation components
    private let rtcManager: any RtcManaging
    private let sleeper: RoomHeartbeatSleeper

    /// Concurrency control
    private let cycle = RoomHeartbeatCycle()
    private let taskLock = NSLock()

    /// Runtime state
    private var heartbeatTask: Task<Void, Never>?

    /// Creates a room heartbeat component with the specified wait strategy.
    ///
    /// - Parameters:
    ///   - rtcManager: The RTC manager submitting room signals.
    ///   - sleeper: The wait strategy controlling heartbeat intervals.
    init(
        rtcManager: any RtcManaging,
        sleeper: RoomHeartbeatSleeper = .live
    ) {
        self.rtcManager = rtcManager
        self.sleeper = sleeper
    }

    /// Invalidates the heartbeat cycle and cancels its background task.
    deinit {
        cycle.advance()
        heartbeatTask?.cancel()
    }

    /// Replaces the previous cycle and starts room heartbeats for the specified user.
    ///
    /// - Parameter userID: The local user account sending heartbeats.
    func start(userID: String) {
        taskLock.withLock {
            let version = cycle.advance()
            heartbeatTask?.cancel()
            let context = Context(
                rtcManager: rtcManager,
                sleeper: sleeper,
                cycle: cycle,
                version: version,
                userID: userID
            )
            heartbeatTask = Task {
                await Self.run(context)
            }
        }
    }

    /// Invalidates the current cycle and cancels its task.
    func stop() {
        taskLock.withLock {
            cycle.advance()
            heartbeatTask?.cancel()
            heartbeatTask = nil
        }
    }
}

private extension RoomHeartbeat {
    /// Stores send dependencies and validity for one heartbeat cycle.
    struct Context: Sendable {

        /// Send dependencies
        let rtcManager: any RtcManaging
        let sleeper: RoomHeartbeatSleeper

        /// Cycle validity
        let cycle: RoomHeartbeatCycle
        let version: UInt64

        /// Sender identity
        let userID: String
    }

    /// Sends heartbeats using the wait strategy, ignoring late results from stopped cycles.
    ///
    /// - Parameter context: The current cycle's dependencies and identity.
    static func run(_ context: Context) async {
        while context.cycle.isCurrent(context.version) {
            do {
                try await context.sleeper.sleep()
                try Task.checkCancellation()
                guard context.cycle.isCurrent(context.version) else {
                    return
                }
                try context.rtcManager.sendRoomMessage(
                    RoomEvent.heartbeat(userID: context.userID)
                )
            } catch is CancellationError {
                return
            } catch {
                guard context.cycle.isCurrent(context.version) else {
                    return
                }
                XmaxLogger.room.error(
                    message: "发送 RTC 房间心跳失败 (Failed to Send RTC Room Heartbeat)\n└─ \(XmaxLogger.localized("原因：", "Reason: "))" +
                        (error as NSError).localizedDescription
                )
            }
        }
    }
}

/// Provides replaceable room heartbeat waiting behavior.
struct RoomHeartbeatSleeper: Sendable {

    /// Wait strategy
    let sleep: @Sendable () async throws -> Void

    /// Default configuration
    static let live = RoomHeartbeatSleeper {
        try await Task.sleep(nanoseconds: 10_000_000_000)
    }
}

/// Uses versions to isolate old room heartbeat tasks after stop or restart.
private final class RoomHeartbeatCycle: @unchecked Sendable {

    /// Concurrent state
    private let lock = NSLock()
    private var value: UInt64 = 0

    /// Advances heartbeat validity, invalidating earlier cycles.
    ///
    /// - Returns: The updated cycle version.
    @discardableResult
    func advance() -> UInt64 {
        lock.withLock {
            value &+= 1
            return value
        }
    }

    /// Checks whether a heartbeat version is the current cycle.
    ///
    /// - Parameter version: The cycle version to check.
    /// - Returns: `true` if the version remains valid.
    func isCurrent(_ version: UInt64) -> Bool {
        lock.withLock { value == version }
    }
}
