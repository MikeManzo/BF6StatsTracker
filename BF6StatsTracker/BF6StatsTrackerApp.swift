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
    @State private var isWindowVisible = true
    @Environment(\.openWindow) private var openWindow

    // SwiftData model container
    let modelContainer: ModelContainer

    init() {
        logInfo("BF6 Stats Tracker starting up...", category: .general)

        do {
            // Configure the schema with all our models
            let schema = Schema([
                StatsSnapshot.self,
                PlaySession.self,
                MapStats.self,
                DailyPerformance.self
            ])

            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            logSuccess("SwiftData initialized successfully", category: .success)
        } catch {
            logError("Could not initialize ModelContainer: \(error)", category: .error)
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(historyManager)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    isWindowVisible = true
                    // Initialize SwiftData managers with context
                    let context = modelContainer.mainContext
                    HistoryManager.shared.setup(modelContext: context)
                    MapTracker.shared.setup(modelContext: context)
                    logSuccess("SwiftData managers initialized", category: .success)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BF6 Stats Tracker") {
                    openWindow(id: "about")
                }
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
        }

        // About Window
        Window("About BF6 Stats Tracker", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(viewModel)
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the app to support both window and menu bar
        NSApp.setActivationPolicy(.regular)
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
}
