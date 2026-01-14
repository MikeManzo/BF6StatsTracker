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
//  LogViewModel.swift
//  BF6StatsTracker
//
//  View model for managing log viewer state and filtering
//

import SwiftUI
import Combine

@MainActor
class LogViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    @Published var selectedCategories: Set<LogCategory> = Set(LogCategory.allCases)
    @Published var autoScroll: Bool {
        didSet {
            UserDefaults.standard.set(autoScroll, forKey: "LogViewer_AutoScroll")
        }
    }
    @Published var reverseOrder: Bool {
        didSet {
            UserDefaults.standard.set(reverseOrder, forKey: "LogViewer_ReverseOrder")
        }
    }
    @Published var selectedEntry: LogEntry?
    @Published private var logEntriesCache: [LogEntry] = []
    @Published private(set) var filteredLogs: [LogEntry] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load persisted preferences
        self.autoScroll = UserDefaults.standard.object(forKey: "LogViewer_AutoScroll") as? Bool ?? true
        self.reverseOrder = UserDefaults.standard.object(forKey: "LogViewer_ReverseOrder") as? Bool ?? false

        // Initial load - must happen first
        logEntriesCache = LoggerService.shared.logEntries

        // Observe logger service for updates
        LoggerService.shared.$logEntries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.logEntriesCache = entries
                self?.updateFilteredLogs()
            }
            .store(in: &cancellables)

        // Observe filter changes
        Publishers.CombineLatest4($searchText, $selectedLevels, $selectedCategories, $reverseOrder)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateFilteredLogs()
            }
            .store(in: &cancellables)

        // Apply initial filters
        updateFilteredLogs()
    }

    /// Update filtered log entries based on current filters
    private func updateFilteredLogs() {
        var logs = logEntriesCache.filter { entry in
            // Filter by level
            guard selectedLevels.contains(entry.level) else { return false }

            // Filter by category
            guard selectedCategories.contains(entry.category) else { return false }

            // Filter by search text
            if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                return entry.message.lowercased().contains(searchLower) ||
                       entry.category.rawValue.lowercased().contains(searchLower) ||
                       entry.level.rawValue.lowercased().contains(searchLower)
            }

            return true
        }

        // Apply sort order
        if reverseOrder {
            logs.reverse()
        }

        filteredLogs = logs
    }

    /// Toggle a log level filter
    func toggleLevel(_ level: LogLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
    }

    /// Toggle a category filter
    func toggleCategory(_ category: LogCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    /// Select all log levels
    func selectAllLevels() {
        selectedLevels = Set(LogLevel.allCases)
    }

    /// Deselect all log levels
    func deselectAllLevels() {
        selectedLevels.removeAll()
    }

    /// Select all categories
    func selectAllCategories() {
        selectedCategories = Set(LogCategory.allCases)
    }

    /// Deselect all categories
    func deselectAllCategories() {
        selectedCategories.removeAll()
    }

    /// Clear all logs
    func clearLogs() {
        LoggerService.shared.clearLogs()
    }

    /// Export logs to file
    func exportLogs() {
        let content = LoggerService.shared.exportLogs()

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "bf6stats-logs-\(Date().timeIntervalSince1970).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                logError("Failed to export logs: \(error.localizedDescription)", category: .error)
            }
        }
    }

    /// Copy log entry to clipboard
    func copyToClipboard(_ entry: LogEntry) {
        let text = "[\(entry.displayTimestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Copy all filtered logs to clipboard
    func copyAllToClipboard() {
        let text = filteredLogs.map { entry in
            "[\(entry.displayTimestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)"
        }.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
