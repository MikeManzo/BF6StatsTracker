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
    @State private var isWindowVisible = true

    // SwiftData model container
    let modelContainer: ModelContainer

    init() {
        do {
            // Configure the schema with all our models
            let schema = Schema([
                StatsSnapshot.self,
                PlaySession.self,
                MapStats.self
            ])

            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            print("✅ SwiftData initialized successfully")
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 1200, minHeight: 800)
                .onAppear {
                    isWindowVisible = true
                    // Initialize SwiftData managers with context
                    let context = modelContainer.mainContext
                    HistoryManager.shared.setup(modelContext: context)
                    MapTracker.shared.setup(modelContext: context)
                    print("✅ SwiftData managers initialized")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Stats") {
                Button("Refresh Stats") {
                    Task {
                        await viewModel.refreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
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
        
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(viewModel)
        } label: {
            Image(systemName: "gamecontroller.fill")
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
