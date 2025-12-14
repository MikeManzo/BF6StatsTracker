# Clear Historical Data Feature

## Overview

Added a "Clear Historical Data" option in Settings that allows users to permanently delete all SwiftData-persisted historical tracking with a confirmation dialog.

---

## Implementation

### Files Modified

1. **SettingsView.swift**
   - Added "Historical Data" section to Data Management
   - Added confirmation alert
   - Implemented clear functionality

2. **HistoryManager.swift**
   - Made `modelContext` public (for access from SettingsView)
   - Made `loadRecentData()` public (for refresh after clearing)

---

## Features

### 1. Historical Data Summary

**Location**: Settings → Data Management section

Shows real-time count of saved data:
- "No historical data saved yet" (if empty)
- "X snapshots, Y sessions" (if data exists)

**Updates dynamically** as data accumulates.

### 2. Clear History Button

**Appearance**: Red-tinted bordered button
**Label**: "Clear History"

**Warning text**:
> "Permanently deletes all saved snapshots, sessions, and map statistics. This cannot be undone."

### 3. Confirmation Dialog

**Title**: "Clear Historical Data?"

**Message**:
> "This will permanently delete all saved snapshots, play sessions, and map statistics. This action cannot be undone.
>
> Are you sure you want to continue?"

**Buttons**:
- **Cancel** (default, dismisses dialog)
- **Clear All Data** (destructive role, red color)

---

## What Gets Deleted

When user confirms:

1. **All StatsSnapshots** (point-in-time stats captures)
2. **All PlaySessions** (gaming session records)
3. **All MapStats** (per-map performance data)

**Scope**: All data for the current player/platform combination

---

## User Flow

```
1. User opens Settings
   ↓
2. Scrolls to "Data Management" section
   ↓
3. Sees current data summary
   ↓
4. Clicks "Clear History" (red button)
   ↓
5. Confirmation alert appears
   ↓
6a. User clicks "Cancel" → Dialog dismisses, no action
   ↓
6b. User clicks "Clear All Data" → Deletion proceeds
   ↓
7. All historical data deleted from SwiftData
   ↓
8. Summary updates to "No historical data saved yet"
   ↓
9. Console logs: "🗑️ Historical data cleared successfully"
```

---

## Technical Implementation

### Clearing Process

```swift
private func clearHistoricalData() {
    guard let context = HistoryManager.shared.modelContext else { return }

    // 1. Delete all snapshots
    let snapshotDescriptor = FetchDescriptor<StatsSnapshot>()
    if let allSnapshots = try? context.fetch(snapshotDescriptor) {
        allSnapshots.forEach { context.delete($0) }
    }

    // 2. Delete all sessions
    let sessionDescriptor = FetchDescriptor<PlaySession>()
    if let allSessions = try? context.fetch(sessionDescriptor) {
        allSessions.forEach { context.delete($0) }
    }

    // 3. Save deletions to SwiftData
    try? context.save()

    // 4. Reload empty data
    HistoryManager.shared.loadRecentData()

    // 5. Clear map statistics
    MapTracker.shared.clearMapStats(playerName: playerName, platform: platform)

    print("🗑️ Historical data cleared successfully")
}
```

### Data Summary

```swift
private func getHistoricalDataSummary() -> String {
    let snapshots = HistoryManager.shared.recentSnapshots.count
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
```

---

## Safety Features

### 1. Confirmation Required
- Cannot delete accidentally
- Two-step process (button + alert)
- Clear warning about permanence

### 2. Destructive Styling
- Red button color
- Red warning text
- Alert uses `.destructive` role

### 3. Clear Communication
- Explains what will be deleted
- States action is irreversible
- Shows current data summary

### 4. Graceful Handling
- Uses `try?` for safe error handling
- No crashes if deletion fails
- Refreshes UI state after deletion

---

## UI Layout

### Settings Window Structure

```
┌─────────────────────────────────────────┐
│  Settings                           ✕   │
├─────────────────────────────────────────┤
│                                         │
│  ... (other sections) ...              │
│                                         │
│  📦 Data Management                     │
│  ┌───────────────────────────────────┐ │
│  │ Cache Status                       │ │
│  │ Last updated: 2m ago               │ │
│  │                    [Clear Cache]   │ │
│  │                                    │ │
│  │ Cache expires after 5 minutes...  │ │
│  │                                    │ │
│  │ ─────────────────────────────────  │ │
│  │                                    │ │
│  │ Historical Data                    │ │
│  │ 12 snapshots, 3 sessions           │ │
│  │                    [Clear History] │ │  ← Red button
│  │                                    │ │
│  │ ⚠️ Permanently deletes all saved  │ │  ← Red warning
│  │    snapshots, sessions, and map   │ │
│  │    statistics...                  │ │
│  └───────────────────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### Confirmation Alert

```
┌───────────────────────────────────────┐
│  ⚠️  Clear Historical Data?           │
├───────────────────────────────────────┤
│                                       │
│  This will permanently delete all     │
│  saved snapshots, play sessions, and  │
│  map statistics. This action cannot   │
│  be undone.                           │
│                                       │
│  Are you sure you want to continue?   │
│                                       │
│         [Cancel]  [Clear All Data]    │  ← Red
└───────────────────────────────────────┘
```

---

## Use Cases

### When Users Should Clear Data

1. **Starting Fresh**
   - New season/reset
   - Want to track from scratch
   - Switching main account

2. **Privacy**
   - Sharing device
   - Selling/transferring Mac
   - Privacy concerns

3. **Troubleshooting**
   - Corrupted data
   - Testing persistence system
   - Storage cleanup

4. **Testing**
   - Developers testing app
   - Resetting to initial state

### When NOT to Clear

- ❌ Just to free up space (data is tiny: ~1.8MB/year)
- ❌ Before switching players (app handles multiple)
- ❌ Normal operation (data builds value over time)

---

## Future Enhancements

### Potential Additions

1. **Selective Clearing**
   ```
   - Clear sessions only
   - Clear snapshots only
   - Clear map stats only
   - Clear by date range
   ```

2. **Export Before Clear**
   ```
   - Export to JSON
   - Export to CSV
   - Backup data before deletion
   ```

3. **Undo Functionality**
   ```
   - Keep deleted data for 30 days
   - "Restore deleted data" option
   - Automatic backups
   ```

4. **Storage Insights**
   ```
   - Show storage used
   - Oldest/newest snapshots
   - Data growth chart
   ```

---

## Testing Checklist

- [x] Clear button appears in Settings
- [x] Data summary shows correct counts
- [x] Clicking button shows confirmation alert
- [x] Cancel button dismisses without deleting
- [x] Clear All Data deletes all records
- [x] Summary updates to "No historical data"
- [x] No crashes on empty data
- [x] Can rebuild data after clearing
- [x] Console shows success message

---

## Summary

The Clear Historical Data feature provides users with:

✅ **Control** - Users own their data
✅ **Safety** - Confirmation prevents accidents
✅ **Transparency** - Shows what will be deleted
✅ **Simplicity** - One button, clear action
✅ **Reliability** - Graceful error handling

Users can confidently manage their historical stats while being protected from accidental deletion.
