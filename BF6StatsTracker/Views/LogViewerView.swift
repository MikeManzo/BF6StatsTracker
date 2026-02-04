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
//  LogViewerView.swift
//  BF6StatsTracker
//
//  Log viewer for displaying application logs in the Tools tab
//

import SwiftUI

struct LogViewerView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    @StateObject private var viewModel = LogViewModel()
    @State private var selectedLogId: UUID?

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Toolbar
            toolbar

            Divider()

            // Log entries
            if viewModel.filteredLogs.isEmpty {
                emptyState
            } else {
                logTable
            }
        }
        .background(Theme.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title)
                    .foregroundColor(accentColor)

                Text("System Logs")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                // Log count
                Text("\(viewModel.filteredLogs.count) entries")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(12)
            }

            Text("Real-time application logs using Apple's Unified Logging System")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Theme.overlayColor)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 12) {
            GlassContainerWrapper(usesGlass: usesGlass) {
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.textSecondary)
                    TextField("Search logs...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
                .frame(maxWidth: 300)

                Spacer()

                // Sort order toggle
                Toggle(isOn: $viewModel.reverseOrder) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.reverseOrder ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        Text(viewModel.reverseOrder ? "Newest First" : "Oldest First")
                            .font(.caption)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(accentColor)

                // Auto-scroll toggle
                Toggle(isOn: $viewModel.autoScroll) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                        Text("Auto-scroll")
                            .font(.caption)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(accentColor)

                // Clear logs
                Button(action: { viewModel.clearLogs() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .cornerRadius(6)
                    .modifier(SubTabGlassModifier(
                        isSelected: true,
                        accentColor: accentColor,
                        usesGlass: usesGlass
                    ))
                    .overlay(
                        !usesGlass ? RoundedRectangle(cornerRadius: 6).stroke(Theme.error.opacity(0.5), lineWidth: 0.5) : nil
                    )
                }
                .buttonStyle(.plain)

                // Copy all
                Button(action: { viewModel.copyAllToClipboard() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .cornerRadius(6)
                    .modifier(SubTabGlassModifier(
                        isSelected: true,
                        accentColor: accentColor,
                        usesGlass: usesGlass
                    ))
                    .overlay(
                        !usesGlass ? RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4), lineWidth: 0.5) : nil
                    )
                }
                .buttonStyle(.plain)

                // Export
                Button(action: { viewModel.exportLogs() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.caption)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.clear)
                    .cornerRadius(6)
                    .modifier(SubTabGlassModifier(
                        isSelected: true,
                        accentColor: accentColor,
                        usesGlass: usesGlass
                    ))
                    .overlay(
                        !usesGlass ? RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4), lineWidth: 0.5) : nil
                    )
                }
                .buttonStyle(.plain)
            }
            }

            // Filters
            GlassContainerWrapper(usesGlass: usesGlass) {
            HStack(spacing: 12) {
                // Level filters
                Text("Level:")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                ForEach(LogLevel.allCases, id: \.self) { level in
                    LogFilterChip(
                        label: level.rawValue,
                        emoji: level.emoji,
                        isSelected: viewModel.selectedLevels.contains(level),
                        color: colorForLevel(level)
                    ) {
                        viewModel.toggleLevel(level)
                    }
                }

                Spacer()

                // Category filters
                Menu {
                    Button(viewModel.selectedCategories.count == LogCategory.allCases.count ? "Deselect All" : "Select All") {
                        if viewModel.selectedCategories.count == LogCategory.allCases.count {
                            viewModel.deselectAllCategories()
                        } else {
                            viewModel.selectAllCategories()
                        }
                    }

                    Divider()

                    ForEach(LogCategory.allCases, id: \.self) { category in
                        Button {
                            viewModel.toggleCategory(category)
                        } label: {
                            HStack {
                                Text("\(category.emoji) \(category.rawValue)")
                                if viewModel.selectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Categories (\(viewModel.selectedCategories.count))")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            }
        }
        .padding()
        .background(Theme.overlayColor)
    }

    // MARK: - Log Table

    private var logTable: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.filteredLogs.enumerated()), id: \.element.id) { index, entry in
                        LogRowView(entry: entry, viewModel: viewModel, accentColor: accentColor)
                            .id(entry.id)
                            .background(
                                selectedLogId == entry.id
                                    ? accentColor.opacity(0.1)
                                    : (index.isMultiple(of: 2) ? Theme.backgroundSecondary.opacity(0.3) : Color.clear)
                            )
                            .onTapGesture {
                                selectedLogId = entry.id
                            }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.filteredLogs.count) {
                if viewModel.autoScroll, let lastEntry = viewModel.filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)

            Text("No logs to display")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)

            if !viewModel.searchText.isEmpty || viewModel.selectedLevels.count < LogLevel.allCases.count || viewModel.selectedCategories.count < LogCategory.allCases.count {
                Text("Try adjusting your filters")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Button("Clear Filters") {
                    viewModel.searchText = ""
                    viewModel.selectAllLevels()
                    viewModel.selectAllCategories()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let entry: LogEntry
    let viewModel: LogViewModel
    let accentColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(entry.displayTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 80, alignment: .leading)

            // Level indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(colorForLevel(entry.level))
                    .frame(width: 6, height: 6)

                Text(entry.level.rawValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(colorForLevel(entry.level))
                    .frame(width: 60, alignment: .leading)
            }

            // Category badge
            Text("\(entry.category.emoji) \(entry.category.rawValue)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(accentColor.opacity(0.2))
                .cornerRadius(4)
                .frame(width: 140, alignment: .leading)

            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Copy button
            Button(action: { viewModel.copyToClipboard(entry) }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contextMenu {
            Button("Copy Message") {
                viewModel.copyToClipboard(entry)
            }

            Button("Copy with Source Location") {
                let text = "[\(entry.displayTimestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)\n  at \(entry.sourceLocation)"
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }

            Divider()

            Text(entry.sourceLocation)
                .font(.caption)
        }
    }

    private func colorForLevel(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Filter Chip

struct LogFilterChip: View {
    let label: String
    let emoji: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled

    private var usesGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                Text(label)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(usesGlass ? Color.clear : (isSelected ? color.opacity(0.2) : Theme.backgroundSecondary))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(usesGlass ? Color.clear : (isSelected ? color : Color.clear), lineWidth: 1)
            )
            .modifier(SubTabGlassModifier(
                isSelected: isSelected,
                accentColor: color,
                usesGlass: usesGlass
            ))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    LogViewerView()
        .frame(width: 1200, height: 800)
}
