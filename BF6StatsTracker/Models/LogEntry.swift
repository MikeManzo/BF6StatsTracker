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
//  LogEntry.swift
//  BF6StatsTracker
//
//  Model representing a single log entry for the log viewer
//

import Foundation
import os.log

/// Log severity level
enum LogLevel: String, CaseIterable, Codable {
    case debug = "Debug"
    case info = "Info"
    case warning = "Warning"
    case error = "Error"

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

/// Log category for organizing logs by subsystem
enum LogCategory: String, CaseIterable, Codable {
    case auth = "Authentication"
    case api = "API"
    case cache = "Cache"
    case network = "Network"
    case storage = "Storage"
    case retry = "Retry"
    case performance = "Performance"
    case calculation = "Calculation"
    case cleanup = "Cleanup"
    case general = "General"
    case success = "Success"
    case error = "Error"

    var emoji: String {
        switch self {
        case .auth: return "🔐"
        case .api: return "📊"
        case .cache: return "💾"
        case .network: return "🌐"
        case .storage: return "📝"
        case .retry: return "🔄"
        case .performance: return "🚀"
        case .calculation: return "🎖️"
        case .cleanup: return "🗑️"
        case .general: return "📋"
        case .success: return "✅"
        case .error: return "❌"
        }
    }

    var subsystem: String {
        return "com.bf6stats.\(self.rawValue.lowercased())"
    }
}

/// A single log entry
struct LogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let file: String
    let function: String
    let line: Int

    init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
    }

    var displayTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: timestamp)
    }

    var fullTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    var sourceLocation: String {
        return "\(file):\(line) \(function)"
    }
}
