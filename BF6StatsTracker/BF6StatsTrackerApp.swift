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
//  BF6StatsTrackerApp.swift
//  BF6StatsTracker
//
//  Battlefield 6 Stats Tracker - macOS Application
//  Uses GameTools.Network API for statistics
//

import SwiftUI
import SwiftData

@main
struct BF6StatsTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = StatsViewModel()
    @StateObject private var historyManager = HistoryManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var updater = UpdaterService.shared
    @State private var isWindowVisible = true
    @Environment(\.openWindow) private var openWindow

    // SwiftData model container
    let modelContainer: ModelContainer

    /// Loads the saved color scheme from UserDefaults before any views are created
    private static func loadSavedColorScheme() {
        if let settingsData = UserDefaults.standard.data(forKey: "appSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            Task { @MainActor in
                ThemeManager.shared.setColorScheme(settings.selectedColorScheme)
            }
        }
    }
    
    init() {
        logInfo("BF6 Stats Tracker starting up...", category: .general)

        do {
            // Configure the schema with all our models
            let schema = Schema([
                StatsSnapshot.self,
                PlaySession.self,
                MapStats.self,
                DailyPerformance.self,
                AICoachAnalysis.self
            ])

            // Explicitly disable CloudKit sync - we use CloudKit only for manual backups
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            logSuccess("SwiftData initialized successfully", category: .success)
            
            // Load saved color scheme before any views are created
            // This ensures Sparkle dialogs use the correct color from the start
            Self.loadSavedColorScheme()
        } catch {
            logError("Could not initialize ModelContainer: \(error)", category: .error)
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // Main Window
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(historyManager)
                .environmentObject(themeManager)
                .environment(\.accentColor, themeManager.accent)
                .tint(themeManager.accent)
                .environment(\.liquidGlassEnabled, viewModel.settings.liquidGlassEnabled)
                .frame(minWidth: 1000, minHeight: 700)
                .preferredColorScheme(viewModel.settings.appearanceMode.colorScheme)
                .onAppear {
                    isWindowVisible = true
                    // Initialize SwiftData managers with context
                    let context = modelContainer.mainContext
                    HistoryManager.shared.setup(modelContext: context)
                    MapTracker.shared.setup(modelContext: context)
                    iCloudBackupService.shared.setup(modelContext: context)
                    logSuccess("SwiftData managers initialized", category: .success)
                    // Sync theme manager with settings
                    themeManager.setColorScheme(viewModel.settings.selectedColorScheme)
                }
                .onChange(of: viewModel.settings.selectedColorScheme) { _, newScheme in
                    themeManager.setColorScheme(newScheme)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BF6 Stats Tracker") {
                    openWindow(id: "about")
                }
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Stats") {
                Button("Refresh Stats") {
                    Task {
                        await viewModel.refreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Rebuild Daily Performance") {
                    if let playerName = viewModel.playerStats?.userName {
                        HistoryManager.shared.rebuildDailyPerformances(playerName: playerName)
                    }
                }

                Button("Clear Cache") {
                    viewModel.clearCache()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
        
        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .environment(\.accentColor, themeManager.accent)
                .tint(themeManager.accent)
                .environment(\.liquidGlassEnabled, viewModel.settings.liquidGlassEnabled)
                .preferredColorScheme(viewModel.settings.appearanceMode.colorScheme)
        }

        // About Window
        Window("About BF6 Stats Tracker", id: "about") {
            AboutView()
                .environmentObject(themeManager)
                .environment(\.accentColor, themeManager.accent)
                .preferredColorScheme(viewModel.settings.appearanceMode.colorScheme)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .environment(\.accentColor, themeManager.accent)
                .environment(\.liquidGlassEnabled, viewModel.settings.liquidGlassEnabled)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var windowCloseObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the app based on menu bar only mode setting
        let menuBarOnlyMode = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")

        if menuBarOnlyMode {
            // Hide dock icon and run as menu bar only app
            NSApp.setActivationPolicy(.accessory)

            // Monitor window close events to hide dock icon again
            windowCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: nil,
                queue: .main
            ) { /*[weak self]*/ notification in
                guard let window = notification.object as? NSWindow else { return }

                // Only hide dock icon for main content windows (not settings or about)
                if window.contentViewController != nil && !window.title.contains("Settings") && !window.title.contains("About") {
                    // Wait a bit to ensure the window is fully closed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Check if any main windows are still visible
                        let hasVisibleMainWindows = NSApp.windows.contains { window in
                            window.isVisible &&
                            window.contentViewController != nil &&
                            !window.title.contains("Settings") &&
                            !window.title.contains("About")
                        }

                        // If no main windows are visible and we're in menu bar only mode, hide the dock icon
                        if !hasVisibleMainWindows && UserDefaults.standard.bool(forKey: "menuBarOnlyMode") {
                            NSApp.setActivationPolicy(.accessory)
                            logInfo("Hiding dock icon - returning to menu bar only mode", category: .general)
                        }
                    }
                }
            }
        } else {
            // Show dock icon and run as regular app
            NSApp.setActivationPolicy(.regular)
        }

        logInfo("App started with activation policy: \(menuBarOnlyMode ? "accessory (menu bar only)" : "regular")", category: .general)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Reopen the main window if all windows are closed
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        return false
    }

    deinit {
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
