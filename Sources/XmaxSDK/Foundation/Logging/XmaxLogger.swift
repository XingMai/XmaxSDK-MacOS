//
//  XmaxLogger.swift
//  XmaxSDK
//  Repo: https://github.com/XingMai/XmaxSDK-MacOS
//
//  Author: 翁跃庭
//  GitHub: https://github.com/WengYuehTing
//
//  Copyright (c) 2026 XMAX.AI PTE. LTD.
//

import Foundation
import OSLog

/// Controls the log types emitted by XmaxSDK.
public struct XmaxLoggerOption: OptionSet, Sendable {

    /// The log type bitmask.
    public let rawValue: UInt

    /// Creates logging options with the specified bitmask.
    ///
    /// - Parameter rawValue: The log type bitmask.
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Business logs for Room, API, Realtime, Storage, and other components.
    public static let business = Self(rawValue: 1 << 0)

    /// RTC performance metrics and performance alarm logs.
    public static let performance = Self(rawValue: 1 << 1)

    /// Enables all XmaxSDK logs.
    public static let all: Self = [.business, .performance]
}

/// Emits system logs with the Xmax prefix and category.
///
/// Callers must not include API keys, tokens, secrets, Authorization, or complete sensitive responses.
struct XmaxLogger: Sendable {

    /// Category loggers
    static let realtime = Self(category: "Realtime")
    static let rtc = Self(category: "RTC")
    static let media = Self(category: "Media")
    static let api = Self(category: "API")
    static let storage = Self(category: "Storage")
    static let room = Self(category: "Room")
    static let stream = Self(category: "Stream")
    static let render = Self(category: "Render")
    static let interaction = Self(category: "Interaction")
    static let permission = Self(category: "Permission")

    /// Log category
    private let category: String

    /// Logging configuration
    private static let state = XmaxLoggerState()

    /// Platform resources
    private static let logger = Logger(
        subsystem: "ai.xmax.XmaxSDK",
        category: "XmaxSDK"
    )

    /// Creates a logger with the specified category prefix.
    ///
    /// - Parameter category: The business category name in the log prefix.
    private init(category: String) {
        self.category = category
    }

    /// Updates global log options and detail language, replacing the previous configuration.
    ///
    /// - Parameters:
    ///   - options: The log types permitted for output.
    ///   - environment: The service environment selecting the log detail language.
    static func configure(
        options: XmaxLoggerOption,
        environment: XmaxEnvironment = .china
    ) {
        state.update(options, environment: environment)
    }

    /// Selects log detail language for the current environment.
    ///
    /// - Parameters:
    ///   - chinese: The Chinese text for the domestic environment.
    ///   - english: The English text for the overseas environment.
    /// - Returns: The text for the current environment.
    static func localized(_ chinese: String, _ english: String) -> String {
        state.environment == .china ? chinese : english
    }

    /// Checks whether all specified log types are enabled.
    ///
    /// - Parameter option: The log options to check; empty options are disabled.
    /// - Returns: `true` if configuration includes every specified option.
    static func isEnabled(_ option: XmaxLoggerOption) -> Bool {
        state.isEnabled(option)
    }

    /// Emits a debug log, building the message only when its options are enabled.
    ///
    /// - Parameters:
    ///   - message: The log message, evaluated lazily when output is enabled.
    ///   - option: The options controlling this log entry.
    func debug(
        message: @autoclosure () -> String,
        option: XmaxLoggerOption = .business
    ) {
        write(
            level: .debug,
            message: message,
            option: option
        )
    }

    /// Emits an informational log, building the message only when its options are enabled.
    ///
    /// - Parameters:
    ///   - message: The log message, evaluated lazily when output is enabled.
    ///   - option: The options controlling this log entry.
    func info(
        message: @autoclosure () -> String,
        option: XmaxLoggerOption = .business
    ) {
        write(
            level: .info,
            message: message,
            option: option
        )
    }

    /// Emits a warning log, building the message only when its options are enabled.
    ///
    /// - Parameters:
    ///   - message: The log message, evaluated lazily when output is enabled.
    ///   - option: The options controlling this log entry.
    func warn(
        message: @autoclosure () -> String,
        option: XmaxLoggerOption = .business
    ) {
        write(
            level: .warning,
            message: message,
            option: option
        )
    }

    /// Emits an error log, building the message only when its options are enabled.
    ///
    /// - Parameters:
    ///   - message: The log message, evaluated lazily when output is enabled.
    ///   - option: The options controlling this log entry.
    func error(
        message: @autoclosure () -> String,
        option: XmaxLoggerOption = .business
    ) {
        write(
            level: .error,
            message: message,
            option: option
        )
    }

    /// Prefixes every log line with the SDK name and business category.
    ///
    /// - Parameter message: The unprefixed log message.
    /// - Returns: The log text with a consistent category prefix on every line.
    func formattedMessage(message: String) -> String {
        let prefix = "[Xmax][\(category)]"

        return message
            .components(separatedBy: "\n")
            .map { "\(prefix) \($0)" }
            .joined(separator: "\n")
    }

    /// Checks output options and writes a system log at the specified level.
    ///
    /// - Parameters:
    ///   - level: The severity of this log entry.
    ///   - message: The message closure, invoked only when output is enabled.
    ///   - option: The log options controlling output.
    private func write(
        level: Level,
        message: () -> String,
        option: XmaxLoggerOption
    ) {
        guard Self.state.isEnabled(option) else {
            return
        }

        let formatted = formattedMessage(
            message: message()
        )
        switch level {
        case .debug:
            Self.logger.debug("\(formatted, privacy: .public)")
        case .info:
            Self.logger.info("\(formatted, privacy: .public)")
        case .warning:
            Self.logger.warning("\(formatted, privacy: .public)")
        case .error:
            Self.logger.error("\(formatted, privacy: .public)")
        }
    }

    /// Distinguishes system log severity levels.
    private enum Level {
        case debug
        case info
        case warning
        case error
    }
}

/// Stores global SDK log configuration in a thread-safe manner.
final class XmaxLoggerState: @unchecked Sendable {

    /// Concurrency control
    private let lock = NSLock()

    /// Logging configuration
    private var options: XmaxLoggerOption = []
    private var storedEnvironment: XmaxEnvironment = .china

    /// Current language environment
    var environment: XmaxEnvironment {
        lock.withLock { storedEnvironment }
    }

    /// Updates global log configuration in a thread-safe manner.
    ///
    /// - Parameters:
    ///   - options: The log types permitted for output.
    ///   - environment: The service environment selecting the detail language.
    func update(
        _ options: XmaxLoggerOption,
        environment: XmaxEnvironment = .china
    ) {
        lock.lock()
        self.options = options
        storedEnvironment = environment
        lock.unlock()
    }

    /// Checks whether all specified log types are enabled.
    ///
    /// - Parameter option: The log options to check; empty options are disabled.
    /// - Returns: `true` if configuration includes every specified option.
    func isEnabled(_ option: XmaxLoggerOption) -> Bool {
        guard !option.isEmpty else {
            return false
        }

        lock.lock()
        let enabled = options.contains(option)
        lock.unlock()
        return enabled
    }
}
