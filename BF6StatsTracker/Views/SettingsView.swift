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
//  SettingsView.swift
//  BF6StatsTracker
//
//  Settings and preferences for the application
//  Styled to match macOS System Settings
//

import SwiftUI
import SwiftData

// MARK: - Settings Category Enum

enum SettingsCategory: String, CaseIterable, Identifiable {
    case accounts = "EA Accounts"
    case appearance = "Appearance"
    case display = "Display"
    case tabs = "Tabs"
    case sound = "Sound"
    case autoRefresh = "Auto Refresh"
    case menuBar = "Menu Bar"
    case dataManagement = "Data Management"
    case experimental = "Experimental"
    case debug = "Debug"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .accounts: return "person.crop.circle.fill"
        case .appearance: return "paintbrush.fill"
        case .display: return "display"
        case .tabs: return "square.grid.3x3.fill"
        case .sound: return "speaker.wave.3.fill"
        case .autoRefresh: return "arrow.clockwise"
        case .menuBar: return "menubar.rectangle"
        case .dataManagement: return "externaldrive.fill.badge.icloud"
        case .experimental: return "flask.fill"
        case .debug: return "ladybug.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .accounts: return .blue
        case .appearance: return .purple
        case .display: return .indigo
        case .tabs: return .cyan
        case .sound: return .pink
        case .autoRefresh: return .green
        case .menuBar: return .gray
        case .dataManagement: return .orange
        case .experimental: return Theme.bf6Purple
        case .debug: return .red
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var accountStore = EAAccountStore.shared

    @Query(sort: \StatsSnapshot.timestamp, order: .reverse)
    private var allSnapshots: [StatsSnapshot]

    @State private var selectedCategory: SettingsCategory? = .accounts
    @State private var searchText = ""

    // Settings state
    @State private var autoRefresh: Bool = true
    @State private var refreshInterval: Double = 300
    @State private var showNotifications: Bool = true
    @State private var compactMode: Bool = false
    @State private var selectedColorScheme: AppColorScheme = .orange
    @State private var debugMode: Bool = false
    @State private var playSoundOnSnapshot: Bool = true
    @State private var menuBarOnlyMode: Bool = false
    @State private var appearanceMode: AppearanceMode = .auto
    @State private var selectedSound: String = "Glass"
    @State private var showClearHistoryConfirmation = false
    @State private var accountToDelete: StoredEAAccount?
    @State private var showDeleteAccountAlert = false
    @State private var aiCoachEnabled: Bool = false
    @State private var liquidGlassEnabled: Bool = true
    @State private var iCloudBackupEnabled: Bool = false
    @State private var backupFrequency: BackupFrequency = .afterEachMatch
    @StateObject private var backupService = iCloudBackupService.shared
    @State private var showDeleteBackupConfirmation = false

    private var filteredCategories: [SettingsCategory] {
        if searchText.isEmpty {
            return SettingsCategory.allCases
        }
        return SettingsCategory.allCases.filter {
            $0.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Category list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filteredCategories) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                SettingsSidebarRow(
                                    category: category,
                                    isSelected: selectedCategory == category
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(minWidth: 220)
            .background(Color(nsColor: .windowBackgroundColor))
        } detail: {
            // Detail pane
            if let category = selectedCategory {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Category header
                        Text(category.rawValue)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .padding(.bottom, 16)

                        // Content based on category
                        settingsContent(for: category)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                Text("Select a category")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 780, height: 580)
        .tint(themeManager.accent)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
        .alert("Clear Historical Data?", isPresented: $showClearHistoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                clearHistoricalData()
            }
        } message: {
            Text("This will permanently delete all saved snapshots, play sessions, and map statistics. This action cannot be undone.")
        }
        .alert("Delete EA Account", isPresented: $showDeleteAccountAlert, presenting: accountToDelete) { account in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                accountStore.deleteAccount(account)
            }
        } message: { account in
            Text("Are you sure you want to delete the EA account for \(account.nickname ?? account.eaId)?")
        }
        .alert("Delete iCloud Backup?", isPresented: $showDeleteBackupConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Backup", role: .destructive) {
                Task {
                    do {
                        try await backupService.deleteBackupFromICloud()
                    } catch {
                        // Error handling is done in the service
                    }
                }
            }
        } message: {
            Text("This will permanently delete all backed up data from iCloud. Your local data will not be affected. This action cannot be undone.")
        }
    }

    // MARK: - Settings Content Router

    @ViewBuilder
    private func settingsContent(for category: SettingsCategory) -> some View {
        switch category {
        case .accounts:
            accountsPane
        case .appearance:
            appearancePane
        case .display:
            displayPane
        case .tabs:
            tabsPane
        case .sound:
            soundPane
        case .autoRefresh:
            autoRefreshPane
        case .menuBar:
            menuBarPane
        case .dataManagement:
            dataManagementPane
        case .experimental:
            experimentalPane
        case .debug:
            debugPane
        }
    }

    // MARK: - Accounts Pane

    private var accountsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            if accountStore.accounts.isEmpty {
                SettingsGroupBox {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No EA accounts stored")
                                .font(.headline)
                            Text("EA accounts are automatically saved when you authenticate through the app.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(accountStore.accounts) { account in
                    SettingsGroupBox {
                        EAAccountRow(
                            account: account,
                            isCurrentUser: isCurrentUser(account),
                            onDelete: {
                                accountToDelete = account
                                showDeleteAccountAlert = true
                            }
                        )
                    }
                }

                if accountStore.accounts.count > 1 {
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            accountStore.clearAllAccounts()
                        } label: {
                            Text("Remove All Accounts")
                        }
                    }
                    .padding(.top, 8)
                }
            }

            Text("Stored accounts allow quick switching between players without re-authenticating.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Appearance Pane

    private var appearancePane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Appearance")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 20) {
                        ForEach(AppearanceMode.allCases) { mode in
                            AppearanceOptionButton(
                                mode: mode,
                                isSelected: appearanceMode == mode
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appearanceMode = mode
                                    saveSettings()
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }

            Text("Adjust the appearance of BF6 Stats Tracker. Selecting Auto will automatically adjust the appearance based on your system settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Liquid Glass toggle — only shown on macOS 26 (Tahoe) and later
            if #available(macOS 26, *) {
                SettingsGroupBox {
                    SettingsToggleRow(
                        title: "Liquid Glass",
                        subtitle: "Use the system Liquid Glass material on navigation chrome and toolbar buttons",
                        isOn: $liquidGlassEnabled
                    )
                    .onChange(of: liquidGlassEnabled) { _, _ in saveSettings() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Display Pane

    private var displayPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Accent Color
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Accent Color")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 16) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            AccentColorButton(
                                scheme: scheme,
                                isSelected: selectedColorScheme == scheme
                            ) {
                                selectedColorScheme = scheme
                                Theme.setAccentScheme(scheme)
                                themeManager.setColorScheme(scheme)
                                saveSettings()
                            }
                        }
                        Spacer()
                    }
                }
            }

            // Display Options
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsToggleRow(
                        title: "Compact Mode",
                        subtitle: "Use a more compact layout for the main interface",
                        isOn: $compactMode
                    )
                    .onChange(of: compactMode) { _, _ in saveSettings() }

                    Divider()
                        .padding(.vertical, 12)

                    SettingsToggleRow(
                        title: "Show Notifications",
                        subtitle: "Display notifications when stats are updated",
                        isOn: $showNotifications
                    )
                    .onChange(of: showNotifications) { _, _ in saveSettings() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Tabs Pane
    
    private var orderedTabsForSettings: [MainTab] {
        // If custom order is defined, use it
        if !viewModel.settings.tabOrder.isEmpty {
            var orderedTabs: [MainTab] = []
            
            // Add tabs in custom order
            for tabName in viewModel.settings.tabOrder {
                if let tab = MainTab.allCases.first(where: { $0.rawValue == tabName }) {
                    orderedTabs.append(tab)
                }
            }
            
            // Add any remaining tabs that aren't in the custom order (newly added tabs)
            for tab in MainTab.allCases {
                if !orderedTabs.contains(tab) {
                    orderedTabs.append(tab)
                }
            }
            
            return orderedTabs
        }
        
        // Use default order
        return Array(MainTab.allCases)
    }
    
    private func moveTabInSettings(from source: MainTab, to destination: MainTab) {
        let allTabs = MainTab.allCases.map { $0.rawValue }
        
        // Initialize tabOrder if it's empty
        if viewModel.settings.tabOrder.isEmpty {
            viewModel.settings.tabOrder = allTabs
        }
        
        guard let sourceIndex = viewModel.settings.tabOrder.firstIndex(of: source.rawValue),
              let destIndex = viewModel.settings.tabOrder.firstIndex(of: destination.rawValue) else {
            return
        }
        
        withAnimation {
            viewModel.settings.tabOrder.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex)
        }
        
        saveSettings()
    }
    
    private var tabsPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Show or hide navigation tabs. Drag tabs to reorder them.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(orderedTabsForSettings.enumerated()), id: \.element) { index, tab in
                        let isHidden = viewModel.settings.hiddenTabs.contains(tab.rawValue)
                        
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16)
                            
                            Image(systemName: tab.icon)
                                .font(.title3)
                                .foregroundColor(isHidden ? .secondary : accentColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tab.rawValue)
                                    .font(.body)
                                    .foregroundColor(isHidden ? .secondary : Theme.textPrimary)
                                
                                if tab.isExperimental {
                                    Text("Experimental")
                                        .font(.caption2)
                                        .foregroundColor(Theme.bf6Purple)
                                }
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { !isHidden },
                                set: { isVisible in
                                    if isVisible {
                                        viewModel.settings.hiddenTabs.remove(tab.rawValue)
                                    } else {
                                        viewModel.settings.hiddenTabs.insert(tab.rawValue)
                                        // If hiding the currently selected tab, switch to first visible
                                        if viewModel.selectedMainTab == tab {
                                            if let firstVisible = viewModel.visibleMainTabs.first {
                                                viewModel.selectedMainTab = firstVisible
                                                viewModel.selectedSubTab = firstVisible.defaultSubTab
                                            }
                                        }
                                    }
                                    saveSettings()
                                }
                            ))
                            .labelsHidden()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .onDrag {
                            NSItemProvider(object: tab.rawValue as NSString)
                        }
                        .onDrop(of: [.text], delegate: SettingsTabDropDelegate(
                            tab: tab,
                            tabs: orderedTabsForSettings,
                            onMove: { from, to in
                                moveTabInSettings(from: from, to: to)
                            }
                        ))
                        
                        if index < orderedTabsForSettings.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Drag the handle to reorder tabs. Right-click any tab in the main window to quickly hide it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sound Pane

    private var soundPane: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Sound enabled toggle
            SettingsGroupBox {
                SettingsToggleRow(
                    title: "Play Sound on Update",
                    subtitle: "Play a notification sound when new data is available",
                    isOn: $playSoundOnSnapshot
                )
                .onChange(of: playSoundOnSnapshot) { _, _ in saveSettings() }
            }

            // Sound selection
            if playSoundOnSnapshot {
                SettingsGroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notification Sound")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 2) {
                            ForEach(SystemSound.allSounds, id: \.name) { sound in
                                SoundOptionRow(
                                    sound: sound,
                                    isSelected: selectedSound == sound.name,
                                    onSelect: {
                                        selectedSound = sound.name
                                        saveSettings()
                                    },
                                    onTest: {
                                        NSSound(named: NSSound.Name(sound.name))?.play()
                                    }
                                )

                                if sound.name != SystemSound.allSounds.last?.name {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }

            Text("Choose which sound to play when a snapshot is saved after completing a match.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Auto Refresh Pane

    private var autoRefreshPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsToggleRow(
                        title: "Auto Refresh",
                        subtitle: "Automatically refresh stats at regular intervals",
                        isOn: $autoRefresh
                    )
                    .onChange(of: autoRefresh) { _, _ in saveSettings() }

                    if autoRefresh {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Refresh Interval")
                                    .font(.body)
                                Spacer()
                                Text("\(Int(refreshInterval / 60)) minutes")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            Slider(value: $refreshInterval, in: 60...1800, step: 60)
                                .tint(themeManager.accent)
                                .onChange(of: refreshInterval) { _, _ in saveSettings() }

                            HStack {
                                Text("1 min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("30 min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Text("When enabled, the app will automatically fetch new stats at the specified interval.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Menu Bar Pane

    private var menuBarPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsToggleRow(
                        title: "Menu Bar Only Mode",
                        subtitle: "Hide the dock icon and run exclusively from the menu bar",
                        isOn: $menuBarOnlyMode
                    )
                    .onChange(of: menuBarOnlyMode) { oldValue, newValue in
                        if oldValue != newValue {
                            saveSettings()
                        }
                    }

                    if menuBarOnlyMode {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(themeManager.accent)
                            Text("The app will restart to apply this change")
                                .font(.subheadline)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeManager.accent.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Text("When enabled, the app will not appear in the Dock. You can still access all features from the menu bar icon.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data Management Pane

    private var dataManagementPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Cache
            SettingsGroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cache")
                            .font(.headline)
                        Text(viewModel.formatCacheAge())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Clear") {
                        viewModel.clearCache()
                    }.help("Clear Cache")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Cache expires after 5 minutes. Data is stored locally for faster loading.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Historical Data
            SettingsGroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Historical Data")
                            .font(.headline)
                        Text(getHistoricalDataSummary())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Clear", role: .destructive) {
                        showClearHistoryConfirmation = true
                    }.help("Clear Historical Data")
                    .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Clearing history will permanently delete all saved snapshots, sessions, and map statistics.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // iCloud Backup
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SettingsToggleRow(
                            title: "iCloud Backup",
                            subtitle: "Automatically backup all snapshot data to iCloud (1GB free storage)",
                            isOn: $iCloudBackupEnabled
                        )
                        .onChange(of: iCloudBackupEnabled) { _, _ in saveSettings() }
                        
                        if !backupService.isICloudAvailable {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .help("iCloud is not available. Sign in to iCloud in System Settings.")
                        }
                    }
                    
                    if iCloudBackupEnabled {
                        Divider()
                        
                        // Backup Frequency
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Backup Frequency")
                                .font(.body)
                            
                            Picker("", selection: $backupFrequency) {
                                ForEach(BackupFrequency.allCases) { freq in
                                    Text(freq.rawValue).tag(freq)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: backupFrequency) { _, _ in saveSettings() }
                            
                            Text(backupFrequency.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Backup Status
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Last backup: \(backupService.status.formattedLastBackup)")
                                    .font(.subheadline)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                Text("Storage used: \(backupService.status.formattedStorageSize) / 1 GB")
                                    .font(.subheadline)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "photo.stack.fill")
                                    .foregroundColor(.purple)
                                Text("Snapshots backed up: \(backupService.status.snapshotCount)")
                                    .font(.subheadline)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeManager.accent.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    do {
                                        try await backupService.backupToICloud(settings: viewModel.settings)
                                    } catch {
                                        // Error handling is done in the service
                                    }
                                }
                            } label: {
                                if backupService.isBackingUp {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Text("Backup Now")
                                }
                            }
                            .disabled(backupService.isBackingUp || backupService.isRestoring)
                            
                            Button {
                                Task {
                                    do {
                                        let result = try await backupService.restoreFromICloud()
                                        logSuccess("Restored \(result.snapshotsRestored) snapshots and \(result.dailyPerformancesRestored) daily performances", category: .success)
                                        // Refresh history manager
                                        if let playerName = viewModel.playerStats?.userName {
                                            HistoryManager.shared.loadDailyPerformances(playerName: playerName)
                                            HistoryManager.shared.loadRecentData()
                                        }
                                    } catch {
                                        // Error handling is done in the service
                                    }
                                }
                            } label: {
                                if backupService.isRestoring {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Text("Restore from iCloud")
                                }
                            }
                            .disabled(backupService.isBackingUp || backupService.isRestoring)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Delete Backup Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Delete Backup")
                                .font(.headline)
                            
                            Text("Permanently delete all backed up data from iCloud. This will not affect your local data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(role: .destructive) {
                                showDeleteBackupConfirmation = true
                            } label: {
                                Text("Delete iCloud Backup")
                            }
                            .disabled(backupService.status.snapshotCount == 0)
                        }
                        
                        // Error Message
                        if let error = backupService.lastError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            
            Text("Your data is encrypted and stored in your personal iCloud account. Requires iCloud to be enabled in System Settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Experimental Pane

    private var experimentalPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SettingsToggleRow(
                            title: "AI Coach",
                            subtitle: "On-device AI-powered coaching that analyzes your gameplay",
                            isOn: $aiCoachEnabled
                        )
                        .onChange(of: aiCoachEnabled) { _, _ in saveSettings() }

                        Text("BETA")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeManager.accent)
                            .cornerRadius(4)
                    }

                    if aiCoachEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureInfoRow(icon: "cpu", text: "Runs entirely on your Mac using Apple Silicon", color: themeManager.accent)
                            FeatureInfoRow(icon: "memorychip", text: "Uses ~2GB RAM only when AI Coach tab is open", color: themeManager.accent)
                            FeatureInfoRow(icon: "lock.shield", text: "Your data never leaves your device", color: themeManager.accent)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeManager.accent.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Text("Experimental features may be unstable or change significantly in future updates.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Debug Pane

    private var debugPane: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroupBox {
                SettingsToggleRow(
                    title: "Synthetic Snapshot Data",
                    subtitle: "Generate test data for development and testing",
                    isOn: $debugMode
                )
                .onChange(of: debugMode) { _, _ in saveSettings() }
            }

            Text("These options are intended for development and testing purposes only.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func loadCurrentSettings() {
        autoRefresh = viewModel.settings.autoRefresh
        refreshInterval = viewModel.settings.refreshInterval
        showNotifications = viewModel.settings.showNotifications
        compactMode = viewModel.settings.compactMode
        selectedColorScheme = viewModel.settings.selectedColorScheme
        debugMode = viewModel.settings.debugMode
        playSoundOnSnapshot = viewModel.settings.playSoundOnSnapshot
        selectedSound = viewModel.settings.selectedSound
        menuBarOnlyMode = viewModel.settings.menuBarOnlyMode
        appearanceMode = viewModel.settings.appearanceMode
        aiCoachEnabled = viewModel.settings.aiCoachEnabled
        liquidGlassEnabled = viewModel.settings.liquidGlassEnabled
        iCloudBackupEnabled = viewModel.settings.iCloudBackupEnabled
        backupFrequency = BackupFrequency(rawValue: viewModel.settings.backupFrequency) ?? .afterEachMatch
        themeManager.setColorScheme(selectedColorScheme)
    }

    private func saveSettings() {
        let previousMenuBarOnlyMode = viewModel.settings.menuBarOnlyMode

        viewModel.settings.autoRefresh = autoRefresh
        viewModel.settings.refreshInterval = refreshInterval
        viewModel.settings.showNotifications = showNotifications
        viewModel.settings.compactMode = compactMode
        viewModel.settings.selectedColorScheme = selectedColorScheme
        viewModel.settings.debugMode = debugMode
        viewModel.settings.playSoundOnSnapshot = playSoundOnSnapshot
        viewModel.settings.selectedSound = selectedSound
        viewModel.settings.menuBarOnlyMode = menuBarOnlyMode
        viewModel.settings.appearanceMode = appearanceMode
        viewModel.settings.aiCoachEnabled = aiCoachEnabled
        viewModel.settings.liquidGlassEnabled = liquidGlassEnabled
        viewModel.settings.iCloudBackupEnabled = iCloudBackupEnabled
        viewModel.settings.backupFrequency = backupFrequency.rawValue
        themeManager.setColorScheme(selectedColorScheme)

        Task {
            await viewModel.saveSettings()

            if previousMenuBarOnlyMode != menuBarOnlyMode {
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        restartApplication()
                    }
                }
            }
        }
    }

    private func restartApplication() {
        guard let bundleURL = Bundle.main.bundleURL as URL? else {
            logError("Failed to get bundle URL for restart", category: .error)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            if let error = error {
                logError("Failed to relaunch app: \(error)", category: .error)
            } else {
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private func getHistoricalDataSummary() -> String {
        let snapshots = allSnapshots.count
        let sessions = HistoryManager.shared.sessions.count

        if snapshots == 0 && sessions == 0 {
            return "No historical data saved yet"
        }

        var parts: [String] = []
        if snapshots > 0 {
            parts.append("\(snapshots) snapshot\(snapshots == 1 ? "" : "s")")
        }
        if sessions > 0 {
            parts.append("\(sessions) session\(sessions == 1 ? "" : "s")")
        }

        return parts.joined(separator: ", ")
    }

    private func isCurrentUser(_ account: StoredEAAccount) -> Bool {
        // Check if this account matches the currently authenticated user
        if let currentNucleusId = viewModel.settings.nucleusId,
           account.nucleusId == currentNucleusId {
            return true
        }
        if let currentPersonaId = viewModel.settings.personaId,
           account.personaId == currentPersonaId {
            return true
        }
        return false
    }

    private func clearHistoricalData() {
        let playerName = viewModel.settings.playerName
        let platform = viewModel.settings.platform

        if let context = HistoryManager.shared.modelContext {
            do {
                let dailyPerfDescriptor = FetchDescriptor<DailyPerformance>()
                let allDailyPerf = try context.fetch(dailyPerfDescriptor)
                allDailyPerf.forEach { context.delete($0) }

                let sessionDescriptor = FetchDescriptor<PlaySession>()
                let allSessions = try context.fetch(sessionDescriptor)
                allSessions.forEach { context.delete($0) }

                let snapshotDescriptor = FetchDescriptor<StatsSnapshot>()
                let allSnapshots = try context.fetch(snapshotDescriptor)
                allSnapshots.forEach { context.delete($0) }
            } catch {
                logWarning("Error clearing historical data: \(error)", category: .general)
                UserDefaults.standard.set(false, forKey: "HasCleanedCorruptDailyPerformance_v1")
            }

            try? context.save()
            HistoryManager.shared.loadRecentData()
        }

        MapTracker.shared.clearMapStats(playerName: playerName, platform: platform.rawValue)
        logInfo("Historical data cleared successfully", category: .cleanup)

        Task {
            await viewModel.forceRefreshStats()
            logInfo("Stats refreshed after clearing history", category: .retry)
        }
    }
}

// MARK: - Sidebar Row

struct SettingsSidebarRow: View {
    @Environment(\.accentColor) private var accentColor
    let category: SettingsCategory
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : category.iconColor)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.white.opacity(0.2) : category.iconColor.opacity(0.15))
                )

            Text(category.rawValue)
                .font(.body)
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Group Box

struct SettingsGroupBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    @Environment(\.accentColor) private var accentColor
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .tint(accentColor)
    }
}

// MARK: - Feature Info Row

struct FeatureInfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Appearance Option Button

struct AppearanceOptionButton: View {
    @Environment(\.accentColor) private var accentColor
    let mode: AppearanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(mode == .dark ? Color(white: 0.15) : Color.white)
                        .frame(width: 80, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                    // Window chrome preview
                    VStack(spacing: 0) {
                        // Title bar
                        HStack(spacing: 4) {
                            Circle().fill(Color.red.opacity(0.8)).frame(width: 6, height: 6)
                            Circle().fill(Color.yellow.opacity(0.8)).frame(width: 6, height: 6)
                            Circle().fill(Color.green.opacity(0.8)).frame(width: 6, height: 6)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 5)

                        Spacer()

                        // Content preview
                        RoundedRectangle(cornerRadius: 2)
                            .fill(mode == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.15))
                            .frame(width: 60, height: 24)
                            .padding(.bottom, 8)
                    }
                    .frame(width: 80, height: 56)

                    if mode == .auto {
                        // Split indicator for auto mode
                        HStack(spacing: 0) {
                            Color.clear
                            Rectangle()
                                .fill(Color(white: 0.15))
                        }
                        .frame(width: 80, height: 56)
                        .cornerRadius(8)
                        .mask(
                            RoundedRectangle(cornerRadius: 8)
                        )
                    }
                }

                Text(mode.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentColor)
                        .font(.caption)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 14, height: 14)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Accent Color Button

struct AccentColorButton: View {
    let scheme: AppColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(scheme.displayColor)
                    .frame(width: 32, height: 32)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    .padding(-3)
            )
        }
        .buttonStyle(.plain)
        .help(scheme.rawValue)
    }
}

// MARK: - EA Account Row

struct EAAccountRow: View {
    @Environment(\.accentColor) private var accentColor
    let account: StoredEAAccount
    let isCurrentUser: Bool
    let onDelete: () -> Void

    @State private var isExpanded: Bool

    init(account: StoredEAAccount, isCurrentUser: Bool = false, onDelete: @escaping () -> Void) {
        self.account = account
        self.isCurrentUser = isCurrentUser
        self.onDelete = onDelete
        // Auto-expand if this is the current user
        self._isExpanded = State(initialValue: isCurrentUser)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                PlayerAvatarView(
                    avatarUrl: account.avatarUrl,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(account.nickname ?? account.eaId)
                            .font(.body)
                            .fontWeight(.medium)

                        if let platform = Platform(apiString: account.platform) {
                            PlatformIconView(platform: platform, size: 10)
                        }

                        if let status = account.status, status.lowercased() == "active" {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accentColor)
                                .font(.caption2)
                        }
                    }

                    Text("Last used: \(account.lastUsedFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            // Expanded details - show ALL fields from StoredEAAccount
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.vertical, 12)

                    // Identity Section
                    Text("Identity")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        EAIdentityRow(label: "EA ID", value: account.eaId)
                        EAIdentityRow(label: "Nucleus ID", value: account.nucleusId)
                        EAIdentityRow(label: "Persona ID", value: account.personaId)

                        if let userId = account.userId, !userId.isEmpty {
                            EAIdentityRow(label: "User ID", value: userId)
                        }

                        if let displayName = account.displayName, !displayName.isEmpty {
                            EAIdentityRow(label: "Display Name", value: displayName)
                        }

                        if let nickname = account.nickname, !nickname.isEmpty {
                            EAIdentityRow(label: "Nickname", value: nickname)
                        }
                    }

                    Divider()
                        .padding(.vertical, 12)

                    // Account Details Section
                    Text("Account Details")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        if let platform = account.platform, !platform.isEmpty {
                            EAIdentityRow(label: "Platform", value: platform.capitalized)
                        }

                        if let platformIcon = account.platformIcon, !platformIcon.isEmpty {
                            EAIdentityRow(label: "Platform Icon", value: platformIcon)
                        }

                        if let status = account.status, !status.isEmpty {
                            EAIdentityRow(label: "Status", value: status.capitalized)
                        }

                        if let subscription = account.subscriptionLevel, !subscription.isEmpty {
                            EAIdentityRow(label: "Subscription", value: subscription)
                        }

                        if let avatarUrl = account.avatarUrl, !avatarUrl.isEmpty {
                            EAIdentityRow(label: "Avatar URL", value: avatarUrl)
                        }
                    }

                    Divider()
                        .padding(.vertical, 12)

                    // Timestamps Section
                    Text("Timestamps")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        EAIdentityRow(label: "Added", value: formatDate(account.addedAt))
                        EAIdentityRow(label: "Last Used", value: formatDate(account.lastUsed))

                        if let createdAt = account.createdAt, !createdAt.isEmpty {
                            EAIdentityRow(label: "EA Created", value: formatAccountDate(createdAt))
                        }
                    }
                }
                .padding(.leading, 52)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatAccountDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }

        return dateString
    }
}

// MARK: - System Sound

struct SystemSound {
    let name: String
    let displayName: String

    static let allSounds: [SystemSound] = [
        SystemSound(name: "Basso", displayName: "Basso"),
        SystemSound(name: "Blow", displayName: "Blow"),
        SystemSound(name: "Bottle", displayName: "Bottle"),
        SystemSound(name: "Frog", displayName: "Frog"),
        SystemSound(name: "Funk", displayName: "Funk"),
        SystemSound(name: "Glass", displayName: "Glass"),
        SystemSound(name: "Hero", displayName: "Hero"),
        SystemSound(name: "Morse", displayName: "Morse"),
        SystemSound(name: "Ping", displayName: "Ping"),
        SystemSound(name: "Pop", displayName: "Pop"),
        SystemSound(name: "Purr", displayName: "Purr"),
        SystemSound(name: "Sosumi", displayName: "Sosumi"),
        SystemSound(name: "Submarine", displayName: "Submarine"),
        SystemSound(name: "Tink", displayName: "Tink")
    ]
}

// MARK: - Sound Option Row

struct SoundOptionRow: View {
    @Environment(\.accentColor) private var accentColor
    let sound: SystemSound
    let isSelected: Bool
    let onSelect: () -> Void
    let onTest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? accentColor : .secondary)
                        .font(.body)

                    Text(sound.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onTest) {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Test sound")
        }
        .padding(.vertical, 2)
    }
}

// MARK: - EA Identity Row

struct EAIdentityRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Tab Drop Delegate

struct SettingsTabDropDelegate: DropDelegate {
    let tab: MainTab
    let tabs: [MainTab]
    let onMove: (MainTab, MainTab) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let sourceTab = info.itemProviders(for: [.text]).first else { return }
        
        sourceTab.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let tabName = String(data: data, encoding: .utf8),
                  let sourceMainTab = MainTab.allCases.first(where: { $0.rawValue == tabName }),
                  sourceMainTab != tab else {
                return
            }
            
            DispatchQueue.main.async {
                onMove(sourceMainTab, tab)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(StatsViewModel())
        .environmentObject(ThemeManager.shared)
}
