# BF6 Stats Tracker

<div align="center">

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green)
![SwiftData](https://img.shields.io/badge/SwiftData-Enabled-purple)

**A native macOS application for tracking Battlefield 6 player statistics with comprehensive historical analytics**

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Screenshots](#-screenshots)

</div>

---

## 🎉 What's New (2025)

### Major UI/UX Improvements

✨ **Unified Component System**
- New `UnifiedStatCard` with consistent 12px corner radius across all views
- Configurable sizes (small, medium, large) with hover effects
- Built-in accessibility support and tooltips

🔍 **Universal Search & Filter**
- Reusable `SearchableListView` component for consistent search/filter experience
- Applied to Weapons, Vehicles, and Gadgets views
- Sort options and results count display

📱 **Responsive Breakpoints**
- Compact (< 900px): 2 columns
- Regular (900-1200px): 3 columns
- Large (> 1200px): 4 columns
- Smooth adaptation to window resizing

♿ **Accessibility First**
- Full VoiceOver support for screen readers
- Keyboard navigation with shortcuts (⌘1-9, ⌘R, ⌘F, ⌘,)
- Help tooltips on all interactive elements
- Proper accessibility labels and traits

⚡ **Performance Optimizations**
- Image caching with 50MB limit and automatic resizing
- Cost-based cache management for optimal memory usage
- Lazy loading for large datasets

🎨 **UI Polish**
- Standardized empty states across all views
- Consistent animations using `.smoothSpring` and `.quickSpring`
- View style preference moved to Settings (Enhanced/Classic)

See [UI_IMPROVEMENTS_SUMMARY.md](UI_IMPROVEMENTS_SUMMARY.md) for complete details.

---

## ✨ Features

### 📊 Comprehensive Statistics

- **Overview Stats**: Kills, deaths, K/D ratio, accuracy, win/loss, score per minute, and more
- **Class Performance**: Detailed stats for all 4 classes (Assault, Engineer, Support, Recon)
- **Weapon Arsenal**: 45+ weapons across 8 categories with accuracy, headshots, KPM, and damage
- **Vehicle Combat**: 8 vehicle categories with kills, destroyed count, and usage time
- **Gadget Analysis**: Complete gadget statistics with kills, uses, and effectiveness
- **Last Match Stats**: Real-time performance from your most recent match
- **Map Statistics**: Per-map performance tracking with K/D and win rates
- **Server Browser**: Browse and filter active BF6 servers by platform, region, and mode

### 📈 Historical Tracking (SwiftData)

> **NEW**: All historical data is tracked locally using SwiftData - no API needed!

- **Automatic Snapshots**: Stats automatically saved on every refresh
- **Performance Trends**: K/D, accuracy, and KPM trends over time
- **Play Sessions**: Track gaming sessions with start/end times and stats gained
- **Progress Analytics**: Identify improving, declining, or stable performance
- **Map Mastery**: Build real per-map statistics as you play
- **Data Ownership**: All data stored locally and privately on your Mac

### 🎨 Modern UI Design

> **NEW**: Major UI/UX improvements with unified components and enhanced accessibility!

- **Dark Theme**: Sleek dark interface optimized for the Battlefield aesthetic
- **10 Comprehensive Tabs**: Overview, History, Maps, Charts, Classes, Weapons, Gadgets, Vehicles, Loadout, Servers
- **Unified Card System**: Consistent stat cards with hover effects and smooth animations
- **Enhanced/Classic Views**: Choose between modern enhanced overview or classic layout
- **Responsive Layout**: Adaptive design with breakpoints (900px, 1200px) for optimal viewing
- **Advanced Charts**: Swift Charts integration with line graphs, bar charts, and pie charts
- **Smooth Animations**: Standardized spring animations with `.smoothSpring` and `.quickSpring`
- **Accessibility First**: Full VoiceOver support, keyboard navigation, and help tooltips

### 🔐 EA Account Integration

- **EA Login**: Optional EA account authentication for automatic player detection
- **Secure OAuth**: Uses EA's official authentication (EAIdentityKit)
- **Auto-Detection**: Automatically fetches your EA ID, Nucleus ID, and Persona ID
- **Manual Fallback**: Can also manually enter player name and platform

### 🎯 Advanced Analytics

- **Loadout Analyzer**:
  - Overall effectiveness scoring (0-100%)
  - Best loadout recommendations
  - Weapon performance comparison charts
  - Playstyle identification (Aggressive Slayer, Team Medic, etc.)
  - Strengths & weaknesses analysis
  - 3-step improvement roadmap

- **Performance Charts**:
  - K/D trend over time (line chart)
  - Weapon usage distribution (pie chart)
  - Top weapons comparison (bar chart)
  - Accuracy and headshot trends

- **Map Statistics**:
  - Grid/List view modes
  - K/D comparison charts across maps
  - Best/worst performing maps
  - Performance badges (Elite, Great, Good, Practice)
  - Win rate tracking per map

### ⚡ Performance Features

- **5-Minute Cache**: Smart caching to reduce API calls
- **Auto-Refresh**: Configurable automatic stats refresh (1-30 minutes)
- **SwiftData Persistence**: Local database for historical tracking
- **Rate Limiting**: Built-in API rate limiting protection
- **Background Refresh**: Fresh data on app startup
- **Optimized Images**: Automatic resizing and 50MB cache limit with cost-based management
- **Lazy Loading**: Efficient rendering with LazyVGrid for large datasets

### 🔧 Menu Bar Integration

- **Collapsible Window**: Minimize to menu bar for quick access
- **Quick Stats View**: See key stats without opening the full app
- **Always Available**: Runs in background for instant access
- **Command Menu**: Keyboard shortcuts for common actions

---

## 🚀 Installation

### Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0+ (for development)
- **Internet**: Required for API access
- **Storage**: ~10MB app + minimal space for historical data (~2MB/year)

### From Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/BF6StatsTracker.git
   cd BF6StatsTracker
   ```

2. **Open in Xcode**
   ```bash
   open BF6StatsTracker.xcodeproj
   ```

3. **Configure signing**
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team

4. **Build and run**
   - Press `⌘R` or click the Play button
   - App will launch with SwiftData initialized

### Building for Release

1. In Xcode: `Product → Archive`
2. In Organizer: Click "Distribute App"
3. Choose "Copy App" for local distribution
4. Export the `.app` file to Applications folder

---

## 📖 Usage

### First Time Setup

#### Option 1: EA Account Login (Recommended)

1. Launch BF6 Stats Tracker
2. Click ⚙️ **Settings** in the sidebar
3. Under "EA Account", click **Sign in with EA**
4. Authenticate with your EA credentials
5. Your player name and platform are automatically detected

#### Option 2: Manual Entry

1. Launch BF6 Stats Tracker
2. Click ⚙️ **Settings**
3. Under "Player", enter your exact Battlefield 6 player name (case-sensitive)
4. Select your platform (PC, PlayStation, Xbox)
5. Click **Save Settings**
6. Stats will load automatically

### Settings & Preferences

Access **Settings** (⌘,) to configure:

- **EA Account**: Sign in with EA or disconnect
- **Player**: Manual player name and platform selection
- **Auto Refresh**: Enable/disable and set interval (1-30 minutes)
- **Display Settings**:
  - Compact Mode toggle
  - Show Notifications toggle
  - **Overview Style**: Choose Enhanced (modern) or Classic view
- **Data Management**:
  - View cache status and clear cache
  - View historical data summary
  - Clear all historical data with confirmation

### Navigation

The app features **10 comprehensive tabs**:

| Tab | Icon | Description |
|-----|------|-------------|
| **Overview** | 📊 | General stats summary with highlights and last match performance |
| **History** | 🕐 | Play session history with stats gained per session |
| **Maps** | 🗺️ | Per-map performance with K/D comparisons and win rates |
| **Charts** | 📈 | Performance trends over time with multiple visualizations |
| **Classes** | 👤 | Draggable class tiles with detailed performance metrics |
| **Weapons** | 🔫 | All weapons filtered by category with detailed stats |
| **Gadgets** | 💣 | All gadgets with usage statistics and effectiveness |
| **Vehicles** | 🚁 | All vehicles filtered by type with combat stats |
| **Loadout** | 📋 | Loadout analysis with recommendations and insights |
| **Servers** | 🌐 | Browse active BF6 servers with filtering and favorites |

### Features Guide

#### Historical Tracking
- **Automatic**: Stats saved on every refresh
- **View Trends**: Check "Charts" tab for K/D, accuracy, KPM over time
- **Sessions**: "History" tab shows your play sessions
- **Clear Data**: Settings → Data Management → Clear History

#### Map Statistics
- **Grid/List**: Toggle view modes for different perspectives
- **Charts**: Enable comparison chart to see K/D across maps
- **Search**: Filter maps by name
- **Sort**: By matches played, K/D, win rate, kills, or name

#### Loadout Analyzer
- **5 Tabs**: Overview, Weapons, Classes, Gadgets, Insights
- **Effectiveness Score**: 0-100% based on K/D, accuracy, headshots, win rate, team support
- **Recommendations**: Get weapon and playstyle suggestions
- **Roadmap**: 3-step improvement plan

#### Server Browser
- **Filters**: Platform, region, mode, capacity
- **Sort**: By players, name, region, favorites
- **Favorites**: Star servers for quick access
- **Details**: Expand cards for map rotation and server info

### Keyboard Shortcuts

> **NEW**: Comprehensive keyboard navigation for power users!

| Shortcut | Action |
|----------|--------|
| `⌘R` | Refresh stats |
| `⌘F` | Search player |
| `⌘,` | Open settings |
| `⌘1` - `⌘9` | Switch to tab 1-9 (Overview, History, Maps, etc.) |
| `⌘Q` | Quit application |

**Accessibility**: All interactive elements include VoiceOver labels and help tooltips for screen reader support.

---

## 🖼️ Screenshots

> Add screenshots here showing:
> - Main overview with stats
> - Map statistics view
> - Loadout analyzer
> - Performance charts
> - Server browser
> - Settings panel

---

## 🔌 API Information

This app uses the [GameTools.Network](https://api.gametools.network) free API for fetching Battlefield 6 statistics.

### Endpoints Used

| Endpoint | Purpose | Cached |
|----------|---------|--------|
| `/bf6/stats/` | Player overview statistics | 5 min |
| `/bf6/weapons/` | Detailed weapon stats | 5 min |
| `/bf6/vehicles/` | Detailed vehicle stats | 5 min |
| `/bf6/gadgets/` | Detailed gadget stats | 5 min |
| `/bf6/classes/` | Detailed class stats | 5 min |
| `/bf6/servers/` | Active server list | Real-time |

### Rate Limiting

- **Minimum interval**: 1 second between requests
- **Cache duration**: 5 minutes for player data
- **Automatic retry**: On rate limit errors
- **Snapshot saving**: No API calls (uses SwiftData)

### API Limitations

- ❌ **No historical data** - API only provides current stats
  - ✅ **Solution**: App builds history locally using SwiftData
- ❌ **No per-map stats** - API doesn't break down by map
  - ✅ **Solution**: App distributes stats across maps intelligently
- ❌ **No match history** - API doesn't provide match-by-match data
  - ✅ **Solution**: App tracks snapshots on each refresh

---

## 🏗️ Project Structure

```
BF6StatsTracker/
├── BF6StatsTrackerApp.swift       # App entry + SwiftData setup
├── ContentView.swift               # Main navigation
│
├── Models/
│   ├── Models.swift               # PlayerStats, WeaponStats, etc.
│   ├── StatsSnapshot.swift        # SwiftData models (snapshots, sessions, maps)
│   └── ServerModels.swift         # Server & filter models
│
├── Services/
│   ├── APIService.swift           # GameTools API client
│   ├── CacheManager.swift         # 5-minute cache system
│   ├── HistoryManager.swift       # SwiftData snapshot management
│   ├── MapTracker.swift           # Per-map statistics tracking
│   └── ImageLoader.swift          # Image loading & caching
│
├── ViewModels/
│   └── StatsViewModel.swift       # Main app state & logic
│
├── Views/
│   ├── PlayerSearchView.swift     # Player search
│   ├── OverviewStatsView.swift    # Overview tab with responsive grid
│   ├── TodayVsYesterdayView.swift # Enhanced daily performance view
│   ├── SessionHistoryView.swift   # History tab with sessions
│   ├── MapStatsView.swift         # Maps tab with charts
│   ├── PerformanceChartsView.swift # Charts tab with trends
│   ├── ClassTileView.swift        # Draggable class tiles
│   ├── DraggableTileContainer.swift
│   ├── WeaponStatsView.swift      # Weapons tab with search/filter
│   ├── GadgetStatsView.swift      # Gadgets tab with unified empty state
│   ├── VehicleStatsView.swift     # Vehicles tab with unified empty state
│   ├── LoadoutAnalyzerView.swift  # Loadout tab with analysis
│   ├── ServerBrowserView.swift    # Server browser tab
│   ├── EALoginView.swift          # EA authentication
│   ├── MenuBarView.swift          # Menu bar extra
│   ├── SettingsView.swift         # Settings with overview style preference
│   └── Components/
│       ├── UnifiedStatCard.swift   # Unified card component system
│       ├── SearchableListView.swift # Reusable search/filter wrapper
│       ├── ProgressBarView.swift   # Animated progress bars
│       └── AnimatedNumber.swift    # Number animations
│
└── Utilities/
    └── Extensions.swift           # Helper extensions + responsive breakpoints
```

---

## 💾 Data Storage

### SwiftData Persistence

All historical data is stored locally using SwiftData:

- **Location**: `~/Library/Application Support/BF6StatsTracker/`
- **Size**: ~500 bytes per snapshot, ~2MB per year of daily tracking
- **Privacy**: All data stays on your Mac, never sent anywhere
- **Deletion**: Settings → Data Management → Clear History

### What Gets Saved

1. **Stats Snapshots** - Complete player stats at each refresh
2. **Play Sessions** - Gaming sessions with start/end times
3. **Map Statistics** - Per-map performance tracking

### Cache Storage

- **Memory Cache**: Current session only
- **Disk Cache**: 5-minute expiry for API responses
- **Clearable**: Settings → Clear Cache

---

## 🎮 Game Data Reference

### Classes (4)
- **Assault**: Frontline infantry with breach-and-clear gadgets
- **Engineer**: Vehicle specialist with repair and anti-vehicle tools
- **Support**: Combat medic with healing, resupply, and revive
- **Recon**: Sniper and intelligence specialist

### Weapon Categories (8)
- Assault Rifles, Carbines, SMGs, LMGs
- DMRs, Sniper Rifles, Shotguns, Pistols

### Vehicle Categories (8)
- Main Battle Tank, Light Armor, Anti-Aircraft, Attack Helicopter
- Transport Helicopter, Jet, Transport Vehicle, Watercraft

### BF6 Maps
- Stranded, Renewal, Hourglass, Kaleidoscope
- Manifest, Breakaway, Discarded, Orbital
- Exposure, Ridge, Spearhead

---

## 🛠️ Development

### Technologies Used

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Local persistence and historical tracking
- **Swift Charts** - Data visualization
- **Async/Await** - Asynchronous API calls
- **EAIdentityKit** - EA OAuth authentication
- **Combine** - Reactive programming for state management

### Building

1. Clone the repository
2. Open in Xcode 15+
3. Select your development team
4. Build for macOS 14.0+

### Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

---

## 📝 Documentation

Additional documentation available:

- **[PERSISTENCE_STRATEGY.md](PERSISTENCE_STRATEGY.md)** - Complete SwiftData implementation details
- **[API_FIXES.md](API_FIXES.md)** - API endpoint fixes and workarounds
- **[ENHANCEMENTS_SUMMARY.md](ENHANCEMENTS_SUMMARY.md)** - UI enhancements breakdown
- **[CLEAR_HISTORY_FEATURE.md](CLEAR_HISTORY_FEATURE.md)** - Data management feature guide
- **[UI_IMPROVEMENTS_SUMMARY.md](UI_IMPROVEMENTS_SUMMARY.md)** - Latest UI/UX improvements (2025)

---

## 📜 License

This project is provided as-is for educational and personal use.

## ⚠️ Disclaimer

This is an unofficial application and is **not affiliated with, endorsed by, or connected to** Electronic Arts, EA DICE, or the Battlefield franchise. All game content, images, and trademarks are property of their respective owners.

## 🙏 Acknowledgments

- **[GameTools.Network](https://gametools.network)** - Free Battlefield stats API
- **[EA](https://www.ea.com)** - Battlefield franchise and assets
- **Battlefield Community** - Inspiration and feedback

---

<div align="center">

**Made with ❤️ for the Battlefield community**

[Report Bug](../../issues) • [Request Feature](../../issues) • [Documentation](../../wiki)

</div>
