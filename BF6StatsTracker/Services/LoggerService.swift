//
// This file is part of BF6StatsTracker.
//
// BF6StatsTracker is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 or later.
//
// Copyright (c) 2026 CitizenCoder
//

//
//  LoggerService.swift
//  BF6StatsTracker
//
//  Centralized logging service using Apple's Unified Logging System (os.Logger)
//  Provides category-based loggers and in-memory log storage for the log viewer
//

import Foundation
import os.log

/// Global logging service using Apple's Unified Logging System
@MainActor
class LoggerService: ObservableObject {
    static let shared = LoggerService()

    /// Maximum number of log entries to keep in memory
    private let maxLogEntries = 5000

    /// Published log entries for the log viewer
    @Published private(set) var logEntries: [LogEntry] = []

    /// Category-specific loggers
    private var loggers: [LogCategory: Logger] = [:]

    private init() {
        // Initialize loggers for each category
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: category.subsystem, category: category.rawValue)
        }
    }

    /// Log a message with the specified level and category
    func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Create log entry for in-memory storage
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line
        )

        // Add to log entries (maintain max size)
        logEntries.append(entry)
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }

        // Explicitly trigger objectWillChange
        objectWillChange.send()

        // Log to Apple's Unified Logging System
        guard let logger = loggers[category] else { return }

        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }

    /// Clear all stored log entries
    func clearLogs() {
        logEntries.removeAll()
    }

    /// Export logs to a formatted string
    func exportLogs() -> String {
        logEntries.map { entry in
            "[\(entry.fullTimestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }

    // MARK: - Convenience Methods

    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func success(_ message: String, category: LogCategory = .success, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Global Convenience Functions

/// Global logging functions for easy migration from print statements
nonisolated func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LoggerService.shared.debug(message, category: category, file: file, function: function, line: line)
    }
}

nonisolated func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LoggerService.shared.info(message, category: category, file: file, function: function, line: line)
    }
}

nonisolated func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LoggerService.shared.warning(message, category: category, file: file, function: function, line: line)
    }
}

nonisolated func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LoggerService.shared.error(message, category: category, file: file, function: function, line: line)
    }
}

nonisolated func logSuccess(_ message: String, category: LogCategory = .success, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LoggerService.shared.success(message, category: category, file: file, function: function, line: line)
    }
}
