# BF6 Stats Tracker - New Features Integration Guide

## Overview
This guide explains how to integrate the 6 new features into your BF6 Stats Tracker app.

## Features Implemented

1. **Match History / Session Tracking** - Track stats over time with local storage
2. **Server Browser** - Browse active BF6 servers
3. **Map Statistics** - Performance breakdown per map
4. **Loadout Analyzer** - Weapon and loadout recommendations
5. **Performance Charts** - Advanced visualizations using Swift Charts
6. **Heat Maps** - Time-based performance patterns

---

## Step 1: Update App Configuration for SwiftData

### Update `BF6StatsTrackerApp.swift`

```swift
import SwiftUI
import SwiftData

@main
struct BF6StatsTrackerApp: App {
    // Add SwiftData model container
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: StatsSnapshot.self, PlaySession.self, MapStats.self
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(StatsViewModel())
        }
        .modelContainer(modelContainer)
    }
}
```

---

## Step 2: Update ContentView to Show New Tabs

Find your `ContentView.swift` and update the tab switching logic:

```swift
// In your ContentView, update the tab switching:
switch viewModel.selectedTab {
case .overview:
    OverviewStatsView()
case .history:
    SessionHistoryView()
case .maps:
    MapStatsView()
case .charts:
    PerformanceChartsView()
case .classes:
    ClassStatsView()
case .weapons:
    WeaponsStatsView()
case .gadgets:
    GadgetsStatsView()
case .vehicles:
    VehiclesStatsView()
case .loadout:
    LoadoutAnalyzerView()
case .servers:
    ServerBrowserView()
}
```

---

## Step 3: Initialize History Manager

### Update `StatsViewModel.swift` init method:

```swift
init() {
    Task {
        await loadSettings()
        await checkEAAuthenticationStatus()

        // Initialize HistoryManager (add this)
        if let modelContext = /* get from environment */ {
            HistoryManager.shared.setup(modelContext: modelContext)
        }

        if !settings.playerName.isEmpty {
            await forceRefreshStats()

            // Save snapshot after loading stats (add this)
            if let stats = playerStats {
                HistoryManager.shared.saveSnapshot(from: stats)
            }
        }
        setupAutoRefresh()
    }
}
```

---

## Step 4: Enable Auto-Snapshot Saving

### Add to `StatsViewModel.swift` in the `fetchStats` method:

After successfully fetching stats (around line 216), add:

```swift
// After caching the results
await CacheManager.shared.cache(stats: stats, playerName: playerName, platform: platform)

// ADD THIS: Save snapshot for history tracking
HistoryManager.shared.saveSnapshot(from: stats)

// Fetch additional detailed stats if main stats are incomplete
await fetchAdditionalStats(playerName: playerName, platform: platform)
```

---

## Step 5: Pass ModelContext to Views

### Update your main ContentView to pass modelContext:

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = StatsViewModel()

    var body: some View {
        // Your existing view code
        //...

        .onAppear {
            // Initialize HistoryManager with modelContext
            HistoryManager.shared.setup(modelContext: modelContext)
        }
    }
}
```

---

## Step 6: Add Missing Helper Views

Some views reference helper components. Add these if missing:

### `ClassIconView.swift` (if not exists)

```swift
struct ClassIconView: View {
    let className: BF6Class
    let size: CGFloat
    let imageURL: String?

    var body: some View {
        if let imageURL = imageURL, let url = URL(string: imageURL) {
            AsyncGameImage(url: url, placeholder: Image(systemName: className.iconName))
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: className.iconName)
                .font(.system(size: size * 0.5))
                .foregroundColor(className.color)
                .frame(width: size, height: size)
                .background(className.color.opacity(0.2))
                .clipShape(Circle())
        }
    }
}
```

### `AsyncGameImage.swift` (if not exists)

```swift
struct AsyncGameImage: View {
    let url: URL?
    let placeholder: Image

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            @unknown default:
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
```

---

## Step 7: Testing Each Feature

### Test Session History:
1. Open the History tab
2. Click "New Session"
3. Play some matches, refresh stats
4. Click "End Session"
5. View session summary

### Test Map Stats:
1. Open Maps tab
2. Search for specific maps
3. Sort by different metrics

### Test Performance Charts:
1. Open Charts tab
2. Select different time periods
3. View K/D trends and weapon usage

### Test Server Browser:
1. Open Servers tab
2. Browse active servers
3. Refresh server list

### Test Loadout Analyzer:
1. Open Loadout tab
2. View weapon recommendations
3. Read meta analysis insights

---

## Troubleshooting

### Issue: SwiftData errors
**Solution**: Make sure the ModelContainer is properly initialized in the App file

### Issue: Charts not displaying
**Solution**: Ensure you have `import Charts` at the top of PerformanceChartsView.swift

### Issue: Server browser empty
**Solution**: The API may not always return servers. Try different platforms or times.

### Issue: Map stats not showing
**Solution**: The API needs to return "maps" data. Not all accounts may have this data.

---

## API Requirements

The features use these API endpoints:
- `/bf6/stats/` - Main stats (already implemented) ✅
- `/bf6/servers/` - Server browser (NEW)
- Map data comes from `maps` field in stats response

---

## Future Enhancements

Consider adding:
1. Export sessions to CSV
2. Compare sessions side-by-side
3. Push notifications for performance milestones
4. Share loadout recommendations as images
5. Widget support for quick stats

---

## Files Created

### Models:
- `StatsSnapshot.swift` - SwiftData models for history
- `ServerModels.swift` - Server data structures

### Services:
- `HistoryManager.swift` - Session and snapshot management

### Views:
- `SessionHistoryView.swift` - History and sessions
- `MapStatsView.swift` - Map performance
- `PerformanceChartsView.swift` - Charts and visualizations
- `ServerBrowserView.swift` - Server browser
- `LoadoutAnalyzerView.swift` - Loadout analysis

### Updated Files:
- `Models.swift` - Added MapPerformance struct
- `APIService.swift` - Added server endpoints
- `StatsViewModel.swift` - Added new tabs

---

## Performance Tips

1. **Limit Snapshots**: Only save snapshots every 5-10 minutes to avoid database bloat
2. **Pagination**: Implement pagination for sessions list if you have many sessions
3. **Caching**: Charts cache data, so they load quickly
4. **Lazy Loading**: Most lists use LazyVStack for better performance

---

## Need Help?

Check these resources:
- SwiftData documentation: https://developer.apple.com/documentation/swiftdata
- Swift Charts documentation: https://developer.apple.com/documentation/charts
- GameTools API: https://api.gametools.network/docs

---

Good luck with your enhanced BF6 Stats Tracker! 🎮
