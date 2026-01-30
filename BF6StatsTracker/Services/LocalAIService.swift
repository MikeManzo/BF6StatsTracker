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
//  LocalAIService.swift
//  BF6StatsTracker
//
//  On-device AI service using MLX for Apple Silicon inference
//  Provides personalized coaching advice based on player statistics
//

import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

// MARK: - AI Coach Response

struct AICoachResponse: Identifiable {
    let id = UUID()
    let playstyle: String
    let playstyleDescription: String
    let strengths: [String]
    let weaknesses: [String]
    let tips: [AICoachTip]
    let sessionInsight: String?
    let trendAnalysis: TrendAnalysis?
    let generatedAt: Date

    static let empty = AICoachResponse(
        playstyle: "Unknown",
        playstyleDescription: "Not enough data to analyze your playstyle.",
        strengths: [],
        weaknesses: [],
        tips: [],
        sessionInsight: nil,
        trendAnalysis: nil,
        generatedAt: Date()
    )
}

// MARK: - Trend Analysis

struct TrendAnalysis: Identifiable {
    let id = UUID()
    let trajectory: PerformanceTrajectory
    let consistency: ConsistencyRating
    let peakPerformance: PeakPerformanceInsight?
    let topWeapon: TopWeaponInsight?
    let sessionLengthImpact: String?
    let momentumStatus: MomentumStatus
    let insights: [TrendInsight]

    enum PerformanceTrajectory: String {
        case improving = "Improving"
        case stable = "Stable"
        case declining = "Declining"
        case volatile = "Volatile"

        var icon: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            case .volatile: return "arrow.up.arrow.down"
            }
        }

        var color: Color {
            switch self {
            case .improving: return .green
            case .stable: return .blue
            case .declining: return .orange
            case .volatile: return .purple
            }
        }
    }

    enum ConsistencyRating: String {
        case veryConsistent = "Very Consistent"
        case consistent = "Consistent"
        case moderate = "Moderate"
        case inconsistent = "Inconsistent"

        var icon: String {
            switch self {
            case .veryConsistent: return "checkmark.seal.fill"
            case .consistent: return "checkmark.circle.fill"
            case .moderate: return "circle.fill"
            case .inconsistent: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .veryConsistent: return .green
            case .consistent: return .blue
            case .moderate: return .yellow
            case .inconsistent: return .orange
            }
        }
    }

    enum MomentumStatus: String {
        case hotStreak = "Hot Streak"
        case warming = "Warming Up"
        case neutral = "Neutral"
        case cooling = "Cooling Down"
        case slump = "In a Slump"

        var icon: String {
            switch self {
            case .hotStreak: return "flame.fill"
            case .warming: return "flame"
            case .neutral: return "minus.circle"
            case .cooling: return "snowflake"
            case .slump: return "cloud.rain.fill"
            }
        }

        var color: Color {
            switch self {
            case .hotStreak: return .red
            case .warming: return .orange
            case .neutral: return .gray
            case .cooling: return .cyan
            case .slump: return .blue
            }
        }
    }
}

struct PeakPerformanceInsight {
    let bestTimeOfDay: String?      // e.g., "Evening (6-10 PM)"
    let bestDayOfWeek: String?      // e.g., "Weekends"
    let recommendation: String
}

struct TopWeaponInsight {
    let weaponName: String
    let weaponType: String
    let weaponImage: String?
    let kills: Int
    let accuracy: Double            // 0.0 to 1.0
    let headshotPercentage: Double  // 0.0 to 1.0
    let killsPerMinute: Double
    let recommendation: String      // Coaching tip for this weapon
}

struct TrendInsight: Identifiable {
    let id = UUID()
    let category: InsightCategory
    let title: String
    let description: String
    let dataPoint: String?  // e.g., "+15% K/D", "2.3 hrs avg"

    enum InsightCategory: String {
        case improvement = "Improvement"
        case warning = "Warning"
        case pattern = "Pattern"
        case recommendation = "Recommendation"

        var icon: String {
            switch self {
            case .improvement: return "arrow.up.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .pattern: return "chart.line.uptrend.xyaxis"
            case .recommendation: return "lightbulb.fill"
            }
        }

        var color: Color {
            switch self {
            case .improvement: return .green
            case .warning: return .orange
            case .pattern: return .blue
            case .recommendation: return .purple
            }
        }
    }
}

struct AICoachTip: Identifiable {
    let id = UUID()
    let category: TipCategory
    let title: String
    let description: String
    let priority: TipPriority

    enum TipCategory: String {
        case accuracy = "Accuracy"
        case positioning = "Positioning"
        case teamplay = "Teamplay"
        case weapons = "Weapons"
        case vehicles = "Vehicles"
        case objectives = "Objectives"
        case general = "General"

        var icon: String {
            switch self {
            case .accuracy: return "target"
            case .positioning: return "mappin.and.ellipse"
            case .teamplay: return "person.3.fill"
            case .weapons: return "scope"
            case .vehicles: return "car.fill"
            case .objectives: return "flag.fill"
            case .general: return "lightbulb.fill"
            }
        }

        var color: Color {
            switch self {
            case .accuracy: return .cyan
            case .positioning: return .orange
            case .teamplay: return .purple
            case .weapons: return .red
            case .vehicles: return .blue
            case .objectives: return .green
            case .general: return .yellow
            }
        }
    }

    enum TipPriority: Int, Comparable {
        case low = 0
        case medium = 1
        case high = 2

        static func < (lhs: TipPriority, rhs: TipPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var color: Color {
            switch self {
            case .low: return Theme.bf6Green
            case .medium: return Theme.bf6Orange
            case .high: return Theme.bf6Red
            }
        }
    }
}

// MARK: - Trend Data Container

/// Raw trend data gathered from HistoryManager for LLM analysis
struct TrendDataContainer {
    // Performance over time
    let kdTrend7Days: [(Date, Double)]
    let kdTrend30Days: [(Date, Double)]
    let kdTrendDirection: TrendDirection

    // Daily performance stats
    let recentDailyPerformances: [DailyPerformance]
    let averageDailyKD: Double
    let kdStandardDeviation: Double
    let bestDay: DailyPerformance?
    let worstDay: DailyPerformance?

    // Time-based patterns
    let weekendAvgKD: Double
    let weekdayAvgKD: Double
    let hourlyPerformance: [HourlyPerformanceData]

    // Session analysis
    let averageSessionLength: TimeInterval
    let sessionsAnalyzed: Int

    // Momentum indicators
    let last3DaysAvgKD: Double
    let previous7DaysAvgKD: Double

    /// Calculate performance change percentage
    var performanceChangePercent: Double {
        guard previous7DaysAvgKD > 0 else { return 0 }
        return ((last3DaysAvgKD - previous7DaysAvgKD) / previous7DaysAvgKD) * 100
    }

    /// Determine if player performs better on weekends
    var weekendPerformanceBonus: Double {
        guard weekdayAvgKD > 0 else { return 0 }
        return ((weekendAvgKD - weekdayAvgKD) / weekdayAvgKD) * 100
    }

    /// Find best hour of day for performance
    var bestHourOfDay: Int? {
        hourlyPerformance.max(by: { $0.avgKD < $1.avgKD })?.hour
    }

    /// Format best time of day as readable string
    var bestTimeOfDayString: String? {
        guard let hour = bestHourOfDay else { return nil }
        switch hour {
        case 5..<12: return "Morning (\(hour)AM - 12PM)"
        case 12..<17: return "Afternoon (12PM - 5PM)"
        case 17..<21: return "Evening (5PM - 9PM)"
        case 21..<24, 0..<5: return "Night (9PM - 5AM)"
        default: return nil
        }
    }
}

// MARK: - Model Status

enum AIModelStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case loading(progress: Double)
    case loaded
    case error(String)
    case generating

    var isReady: Bool {
        if case .loaded = self { return true }
        return false
    }

    var isDownloaded: Bool {
        switch self {
        case .downloaded, .loading, .loaded, .generating:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .notDownloaded: return "Model not downloaded"
        case .downloading(let progress): return "Downloading model... \(Int(progress * 100))%"
        case .downloaded: return "Model ready to load"
        case .loading(let progress): return "Loading model... \(Int(progress * 100))%"
        case .loaded: return "Model ready"
        case .error(let message): return "Error: \(message)"
        case .generating: return "Generating advice..."
        }
    }
}

// MARK: - Model Info

struct AIModelInfo {
    let name: String
    let displayName: String
    let size: String
    let downloadURL: URL
    let files: [String]

    static let phi3Mini = AIModelInfo(
        name: "Phi-3-mini-4k-instruct-4bit",
        displayName: "Phi-3 Mini (4-bit)",
        size: "~2.2 GB",
        downloadURL: URL(string: "https://huggingface.co/mlx-community/Phi-3-mini-4k-instruct-4bit/resolve/main/")!,
        files: [
            "config.json",
            "model.safetensors",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json"
        ]
    )
}

// MARK: - Local AI Service

@MainActor
class LocalAIService: ObservableObject {
    static let shared = LocalAIService()

    @Published var status: AIModelStatus = .notDownloaded
    @Published var lastResponse: AICoachResponse?
    @Published var isModelLoaded: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var currentDownloadFile: String = ""

    private var unloadTimer: Timer?
    private let unloadTimeout: TimeInterval = 300 // 5 minutes

    // Model configuration
    let modelInfo = AIModelInfo.phi3Mini

    // MLX model instance
    private var modelContainer: ModelContainer?
    private var modelLoaded: Bool = false
    private var downloadTask: URLSessionDownloadTask?

    // Generation configuration
    private let maxTokens: Int = 1024
    private let temperature: Float = 0.7

    private init() {
        // Check if model is already downloaded
        Task {
            await checkModelStatus()
        }
    }

    // MARK: - Model Directory

    /// Get the Application Support directory for the app
    var appSupportDirectory: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("BF6StatsTracker", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir
    }

    /// Get the models directory
    var modelsDirectory: URL {
        let modelsDir = appSupportDirectory.appendingPathComponent("Models", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }

        return modelsDir
    }

    /// Get the path for the current model
    var modelDirectory: URL {
        modelsDirectory.appendingPathComponent(modelInfo.name, isDirectory: true)
    }

    /// Check if all model files exist
    var isModelDownloaded: Bool {
        let fileManager = FileManager.default
        for file in modelInfo.files {
            let filePath = modelDirectory.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: filePath.path) {
                return false
            }
        }
        return true
    }

    /// Get total size of downloaded model
    var downloadedModelSize: String {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        for file in modelInfo.files {
            let filePath = modelDirectory.appendingPathComponent(file)
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    // MARK: - Model Status Check

    func checkModelStatus() async {
        if isModelDownloaded {
            status = .downloaded
            logInfo("AI Model found at: \(modelDirectory.path)", category: .general)
        } else {
            status = .notDownloaded
            logInfo("AI Model not found. Download required.", category: .general)
        }
    }

    // MARK: - Model Download

    /// Download the AI model from Hugging Face
    func downloadModel() async {
        guard !status.isDownloaded else {
            logInfo("Model already downloaded", category: .general)
            return
        }

        // Create model directory
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: modelDirectory.path) {
            try? fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        }

        status = .downloading(progress: 0.0)
        downloadProgress = 0.0

        let totalFiles = modelInfo.files.count
        var completedFiles = 0

        for file in modelInfo.files {
            currentDownloadFile = file
            let fileURL = modelInfo.downloadURL.appendingPathComponent(file)
            let destinationURL = modelDirectory.appendingPathComponent(file)

            // Skip if file already exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                completedFiles += 1
                downloadProgress = Double(completedFiles) / Double(totalFiles)
                status = .downloading(progress: downloadProgress)
                continue
            }

            logInfo("Downloading: \(file)", category: .network)

            do {
                let (tempURL, response) = try await URLSession.shared.download(from: fileURL)

                // Check for valid response
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    throw NSError(domain: "Download failed", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode) for \(file)"
                    ])
                }

                // Move to final destination
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempURL, to: destinationURL)

                completedFiles += 1
                downloadProgress = Double(completedFiles) / Double(totalFiles)
                status = .downloading(progress: downloadProgress)

                logSuccess("Downloaded: \(file)", category: .success)

            } catch {
                logError("Failed to download \(file): \(error.localizedDescription)", category: .error)
                status = .error("Failed to download \(file): \(error.localizedDescription)")
                return
            }
        }

        currentDownloadFile = ""
        status = .downloaded
        logSuccess("AI Model download complete!", category: .success)
    }

    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        status = .notDownloaded
        downloadProgress = 0.0
        currentDownloadFile = ""

        // Clean up partial downloads
        try? FileManager.default.removeItem(at: modelDirectory)

        logInfo("Model download cancelled", category: .general)
    }

    /// Delete the downloaded model
    func deleteModel() {
        unloadModel()

        try? FileManager.default.removeItem(at: modelDirectory)
        status = .notDownloaded
        downloadProgress = 0.0

        logInfo("AI Model deleted", category: .general)
    }

    // MARK: - Model Lifecycle

    /// Load the AI model into memory
    func loadModel() async {
        guard status.isDownloaded else {
            status = .error("Model not downloaded")
            return
        }

        guard !modelLoaded else { return }

        status = .loading(progress: 0.0)

        do {
            // Load the model configuration
            status = .loading(progress: 0.1)
            logInfo("Loading model from: \(modelDirectory.path)", category: .general)

            // Create model configuration pointing to the local downloaded model directory
            let modelConfiguration = ModelConfiguration(
                directory: modelDirectory,
                defaultPrompt: "You are a helpful assistant."
            )

            status = .loading(progress: 0.5)
            logInfo("Loading model weights and tokenizer...", category: .general)

            // Load the LLM model container from the local directory
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            )

            // Trigger model warm-up
            status = .loading(progress: 0.8)
            _ = await modelContainer?.perform { _ in
                // Empty warm-up operation
                return ()
            }

            modelLoaded = true
            isModelLoaded = true
            status = .loaded

            logSuccess("AI Coach model loaded into memory", category: .success)
            resetUnloadTimer()

        } catch {
            logError("Failed to load model: \(error.localizedDescription)", category: .error)
            status = .error("Failed to load model: \(error.localizedDescription)")
            modelLoaded = false
            isModelLoaded = false
        }
    }

    /// Unload the AI model from memory
    func unloadModel() {
        unloadTimer?.invalidate()
        unloadTimer = nil

        // Release model resources
        modelContainer = nil
        modelLoaded = false
        isModelLoaded = false

        // Force clear MLX GPU cache and memory
        Memory.clearCache()
        Memory.cacheLimit = 0  // Disable caching to force immediate release

        // Re-enable reasonable cache limit for next load
        Memory.cacheLimit = 512 * 1024 * 1024  // 512MB cache limit

        // Keep status as downloaded if model exists
        if isModelDownloaded {
            status = .downloaded
        } else {
            status = .notDownloaded
        }

        logInfo("AI Coach model unloaded from memory", category: .general)
    }

    /// Reset the auto-unload timer
    private func resetUnloadTimer() {
        unloadTimer?.invalidate()
        unloadTimer = Timer.scheduledTimer(withTimeInterval: unloadTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.unloadModel()
            }
        }
    }

    // MARK: - Coaching Generation

    /// Generate personalized coaching advice based on player stats
    func generateCoachingAdvice(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot],
        trendData: TrendDataContainer? = nil,
        playerNickname: String? = nil
    ) async -> AICoachResponse {
        // Ensure model is loaded
        if !modelLoaded {
            await loadModel()
        }

        guard status == .loaded else {
            return AICoachResponse.empty
        }

        status = .generating

        // Analyze player stats using LLM with rule-based fallback
        let response = await analyzePlayerStats(
            stats: stats,
            dailyPerformances: dailyPerformances,
            recentSnapshots: recentSnapshots,
            trendData: trendData,
            playerNickname: playerNickname
        )

        lastResponse = response

        // Unload model immediately after analysis to free memory
        unloadModel()

        return response
    }

    /// Gather trend data from HistoryManager for analysis
    func gatherTrendData(from historyManager: HistoryManager, days: Int = 30) -> TrendDataContainer {
        let kdTrend7Days = historyManager.getKDTrend(days: 7)
        let kdTrend30Days = historyManager.getKDTrend(days: min(days, 30))
        let kdTrendDirection = historyManager.calculateKDTrend(days: 7)

        let recentPerformances = historyManager.getRecentDailyPerformances(days: days)
        let averageKD = historyManager.getAverageDailyKD(days: days)
        let stdDev = historyManager.getDailyKDStandardDeviation(days: days)
        let bestDay = historyManager.getBestDailyPerformance(days: days)
        let worstDay = historyManager.getWorstDailyPerformance(days: days)

        let (weekendAvg, weekdayAvg) = historyManager.getWeekendVsWeekdayStats(days: days)

        // Get hourly performance from recent snapshots
        let recentSnapshots = historyManager.getRecentSnapshots(limit: 100)
        let hourlyPerformance = historyManager.getHourlyStats(snapshots: recentSnapshots)

        // Calculate session metrics
        let sessions = historyManager.detectSessions(days: days)
        let avgSessionLength = calculateAverageSessionLength(sessions: sessions)

        // Calculate momentum - compare last 3 days vs previous 7
        let last3DaysKD = calculateAverageKD(from: historyManager.getRecentDailyPerformances(days: 3))
        let previous7DaysKD = calculateAverageKD(from: Array(historyManager.getRecentDailyPerformances(days: 10).dropFirst(3)))

        return TrendDataContainer(
            kdTrend7Days: kdTrend7Days,
            kdTrend30Days: kdTrend30Days,
            kdTrendDirection: kdTrendDirection,
            recentDailyPerformances: recentPerformances,
            averageDailyKD: averageKD,
            kdStandardDeviation: stdDev,
            bestDay: bestDay,
            worstDay: worstDay,
            weekendAvgKD: weekendAvg,
            weekdayAvgKD: weekdayAvg,
            hourlyPerformance: hourlyPerformance,
            averageSessionLength: avgSessionLength,
            sessionsAnalyzed: sessions.count,
            last3DaysAvgKD: last3DaysKD,
            previous7DaysAvgKD: previous7DaysKD
        )
    }

    private func calculateAverageSessionLength(sessions: [[StatsSnapshot]]) -> TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        var totalDuration: TimeInterval = 0
        for session in sessions {
            if let first = session.first, let last = session.last {
                totalDuration += last.timestamp.timeIntervalSince(first.timestamp)
            }
        }
        return totalDuration / Double(sessions.count)
    }

    private func calculateAverageKD(from performances: [DailyPerformance]) -> Double {
        let validPerformances = performances.filter { $0.deltaDeaths > 0 }
        guard !validPerformances.isEmpty else { return 0 }
        return validPerformances.reduce(0) { $0 + $1.dailyKD } / Double(validPerformances.count)
    }

    // MARK: - Analysis Engine

    private func analyzePlayerStats(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot],
        trendData: TrendDataContainer?,
        playerNickname: String? = nil
    ) async -> AICoachResponse {
        // Build the prompt for LLM analysis
        let prompt = buildAnalysisPrompt(stats: stats, history: dailyPerformances, trendData: trendData, playerNickname: playerNickname)

        // Try LLM generation first
        if let llmResponse = await generateWithLLM(prompt: prompt),
           let parsedResponse = parseLLMResponse(llmResponse, stats: stats, trendData: trendData) {
            logSuccess("Using LLM-generated coaching advice", category: .success)
            return parsedResponse
        }

        // Fallback to rule-based analysis if LLM fails or returns invalid response
        logInfo("Falling back to rule-based analysis", category: .general)
        return generateRuleBasedAnalysis(
            stats: stats,
            dailyPerformances: dailyPerformances,
            recentSnapshots: recentSnapshots,
            trendData: trendData
        )
    }

    /// Rule-based fallback analysis
    private func generateRuleBasedAnalysis(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot],
        trendData: TrendDataContainer?
    ) -> AICoachResponse {
        // Analyze playstyle
        let (playstyle, playstyleDesc) = determinePlaystyle(stats: stats)

        // Identify strengths
        let strengths = identifyStrengths(stats: stats)

        // Identify weaknesses
        let weaknesses = identifyWeaknesses(stats: stats)

        // Generate tips
        let tips = generateTips(stats: stats, dailyPerformances: dailyPerformances)

        // Session insight
        let sessionInsight = generateSessionInsight(
            stats: stats,
            dailyPerformances: dailyPerformances,
            recentSnapshots: recentSnapshots
        )

        // Generate trend analysis
        let trendAnalysis = generateRuleBasedTrendAnalysis(trendData: trendData, stats: stats)

        return AICoachResponse(
            playstyle: playstyle,
            playstyleDescription: playstyleDesc,
            strengths: strengths,
            weaknesses: weaknesses,
            tips: tips,
            sessionInsight: sessionInsight,
            trendAnalysis: trendAnalysis,
            generatedAt: Date()
        )
    }

    /// Generate rule-based trend analysis when LLM fails
    private func generateRuleBasedTrendAnalysis(trendData: TrendDataContainer?, stats: PlayerStats?) -> TrendAnalysis? {
        guard let data = trendData else { return nil }

        // Determine trajectory
        let trajectory: TrendAnalysis.PerformanceTrajectory
        let changePercent = data.performanceChangePercent
        if changePercent > 10 {
            trajectory = .improving
        } else if changePercent < -10 {
            trajectory = .declining
        } else if data.kdStandardDeviation > 0.5 {
            trajectory = .volatile
        } else {
            trajectory = .stable
        }

        // Determine consistency
        let consistency: TrendAnalysis.ConsistencyRating
        let stdDev = data.kdStandardDeviation
        if stdDev < 0.15 {
            consistency = .veryConsistent
        } else if stdDev < 0.3 {
            consistency = .consistent
        } else if stdDev < 0.5 {
            consistency = .moderate
        } else {
            consistency = .inconsistent
        }

        // Determine momentum
        let momentum: TrendAnalysis.MomentumStatus
        if changePercent > 20 {
            momentum = .hotStreak
        } else if changePercent > 5 {
            momentum = .warming
        } else if changePercent < -20 {
            momentum = .slump
        } else if changePercent < -5 {
            momentum = .cooling
        } else {
            momentum = .neutral
        }

        // Build peak performance insight
        var peakInsight: PeakPerformanceInsight?
        let weekendBonus = data.weekendPerformanceBonus
        if abs(weekendBonus) > 10 || data.bestTimeOfDayString != nil {
            let bestDay = weekendBonus > 10 ? "Weekends" : (weekendBonus < -10 ? "Weekdays" : nil)
            let recommendation: String
            if weekendBonus > 15 {
                recommendation = "Schedule important matches on weekends for optimal performance."
            } else if weekendBonus < -15 {
                recommendation = "You perform better on weekdays - use weekends for practice."
            } else if let time = data.bestTimeOfDayString {
                recommendation = "Your peak performance is during \(time.lowercased())."
            } else {
                recommendation = "Your performance is consistent across different times."
            }

            peakInsight = PeakPerformanceInsight(
                bestTimeOfDay: data.bestTimeOfDayString,
                bestDayOfWeek: bestDay,
                recommendation: recommendation
            )
        }

        // Generate insights
        var insights: [TrendInsight] = []

        // Trajectory insight
        if trajectory == .improving {
            insights.append(TrendInsight(
                category: .improvement,
                title: "Performance Improving",
                description: "Your K/D has improved over the past few days. Keep up the momentum!",
                dataPoint: String(format: "+%.0f%%", changePercent)
            ))
        } else if trajectory == .declining {
            insights.append(TrendInsight(
                category: .warning,
                title: "Performance Dip Detected",
                description: "Your recent sessions show a decline. Consider taking a break or reviewing your loadout.",
                dataPoint: String(format: "%.0f%%", changePercent)
            ))
        }

        // Weekend/weekday pattern
        if abs(weekendBonus) > 15 {
            insights.append(TrendInsight(
                category: .pattern,
                title: weekendBonus > 0 ? "Weekend Warrior" : "Weekday Performer",
                description: weekendBonus > 0
                    ? "You perform \(String(format: "%.0f%%", weekendBonus)) better on weekends."
                    : "You perform \(String(format: "%.0f%%", abs(weekendBonus))) better on weekdays.",
                dataPoint: String(format: "%.0f%% %@", abs(weekendBonus), weekendBonus > 0 ? "↑ weekends" : "↑ weekdays")
            ))
        }

        // Session length insight
        if data.averageSessionLength > 0 {
            let avgHours = data.averageSessionLength / 3600
            if avgHours > 3 {
                insights.append(TrendInsight(
                    category: .recommendation,
                    title: "Consider Shorter Sessions",
                    description: "Your average session is \(String(format: "%.1f", avgHours)) hours. Performance often drops after 2 hours.",
                    dataPoint: String(format: "%.1f hrs avg", avgHours)
                ))
            }
        }

        // Best day highlight
        if let bestDay = data.bestDay, bestDay.dailyKD > data.averageDailyKD * 1.3 {
            insights.append(TrendInsight(
                category: .improvement,
                title: "Best Recent Session",
                description: "On \(formatDate(bestDay.date)), you achieved a \(String(format: "%.2f", bestDay.dailyKD)) K/D with \(bestDay.deltaKills) kills.",
                dataPoint: String(format: "%.2f K/D", bestDay.dailyKD)
            ))
        }

        // Extract top weapon insight
        let topWeaponInsight = extractTopWeaponInsight(from: stats)

        return TrendAnalysis(
            trajectory: trajectory,
            consistency: consistency,
            peakPerformance: peakInsight,
            topWeapon: topWeaponInsight,
            sessionLengthImpact: data.averageSessionLength > 7200 ? "Long sessions may be affecting performance" : nil,
            momentumStatus: momentum,
            insights: insights
        )
    }

    /// Extract top weapon insight from player stats
    private func extractTopWeaponInsight(from stats: PlayerStats?) -> TopWeaponInsight? {
        guard let stats = stats,
              let weapons = stats.weapons,
              !weapons.isEmpty else { return nil }

        // Find the weapon with most kills
        guard let topWeapon = weapons.max(by: { $0.kills < $1.kills }) else { return nil }

        // Don't show if very few kills
        guard topWeapon.kills >= 50 else { return nil }

        // Generate recommendation based on weapon stats
        let recommendation = generateWeaponRecommendation(weapon: topWeapon, playerStats: stats)

        return TopWeaponInsight(
            weaponName: topWeapon.weaponName,
            weaponType: topWeapon.type,
            weaponImage: topWeapon.image,
            kills: topWeapon.kills,
            accuracy: topWeapon.accuracy / 100.0,  // Convert from percentage to 0-1 scale
            headshotPercentage: topWeapon.headshotPercentage / 100.0,
            killsPerMinute: topWeapon.killsPerMinute,
            recommendation: recommendation
        )
    }

    /// Generate a coaching recommendation for the top weapon
    private func generateWeaponRecommendation(weapon: WeaponStats, playerStats: PlayerStats) -> String {
        let accuracy = weapon.accuracy
        let headshotRate = weapon.headshotPercentage
        let kpm = weapon.killsPerMinute

        // Compare to player's overall stats
        let overallAccuracy = playerStats.accuracy
        let overallHeadshotRate = playerStats.headshotPercentage

        if headshotRate > 15 && accuracy > overallAccuracy {
            return "Excellent precision with this weapon! Your headshot rate is exceptional - keep leveraging this strength."
        } else if accuracy < overallAccuracy * 0.8 {
            return "Your accuracy with this weapon is below your average. Consider practicing burst fire or adjusting your aim sensitivity."
        } else if headshotRate < overallHeadshotRate * 0.7 && headshotRate < 10 {
            return "Try aiming higher to increase headshots. This weapon can be lethal with better headshot placement."
        } else if kpm > 0.8 {
            return "High kill rate with this weapon! You're very aggressive and effective - perfect for objective pushes."
        } else if kpm < 0.3 && weapon.kills > 500 {
            return "Consider a more aggressive playstyle with this weapon to increase your kills per minute."
        } else {
            return "This is your go-to weapon. Keep mastering it to maintain your edge in combat."
        }
    }

    /// Build a structured prompt for LLM analysis
    private func buildAnalysisPrompt(stats: PlayerStats, history: [DailyPerformance], trendData: TrendDataContainer?, playerNickname: String? = nil) -> String {
        let playerName = playerNickname ?? stats.userName
        var prompt = """
        Analyze these Battlefield player statistics and provide coaching advice for \(playerName).

        PLAYER STATISTICS:
        - K/D Ratio: \(String(format: "%.2f", stats.kdRatio))
        - Accuracy: \(String(format: "%.1f%%", stats.accuracy))
        - Headshot Rate: \(String(format: "%.1f%%", stats.headshotPercentage))
        - Win Rate: \(String(format: "%.1f%%", stats.wlRatio))
        - Kills per Match: \(String(format: "%.1f", stats.killsPerMatch))
        - Kills per Minute: \(String(format: "%.2f", stats.killsPerMinute))
        - Total Kills: \(stats.kills)
        - Total Deaths: \(stats.deaths)
        - Revives: \(stats.revives)
        - Resupplies: \(stats.resupplies)
        - Vehicles Destroyed: \(stats.vehiclesDestroyed)
        - Best Class: \(stats.bestClass)
        - Matches Played: \(stats.matchesPlayed)
        - Time Played: \(stats.timePlayedString)

        RECENT SESSIONS:
        \(history.prefix(5).map { "- \(formatDate($0.date)): K/D \(String(format: "%.2f", $0.dailyKD)), \($0.deltaKills) kills" }.joined(separator: "\n"))
        """

        // Add trend data if available
        if let trend = trendData {
            prompt += """


        TREND ANALYSIS DATA:
        - 7-Day Average K/D: \(String(format: "%.2f", trend.averageDailyKD))
        - K/D Standard Deviation: \(String(format: "%.2f", trend.kdStandardDeviation)) (lower = more consistent)
        - Last 3 Days Avg K/D: \(String(format: "%.2f", trend.last3DaysAvgKD))
        - Previous 7 Days Avg K/D: \(String(format: "%.2f", trend.previous7DaysAvgKD))
        - Performance Change: \(String(format: "%+.1f%%", trend.performanceChangePercent))
        - Weekend Avg K/D: \(String(format: "%.2f", trend.weekendAvgKD))
        - Weekday Avg K/D: \(String(format: "%.2f", trend.weekdayAvgKD))
        - Weekend vs Weekday Difference: \(String(format: "%+.1f%%", trend.weekendPerformanceBonus))
        - Average Session Length: \(String(format: "%.1f hours", trend.averageSessionLength / 3600))
        - Sessions Analyzed: \(trend.sessionsAnalyzed)
        """

            if let bestTime = trend.bestTimeOfDayString {
                prompt += "\n- Best Time of Day: \(bestTime)"
            }

            if let bestDay = trend.bestDay {
                prompt += "\n- Best Day: \(formatDate(bestDay.date)) with \(String(format: "%.2f", bestDay.dailyKD)) K/D"
            }

            if let worstDay = trend.worstDay {
                prompt += "\n- Worst Day: \(formatDate(worstDay.date)) with \(String(format: "%.2f", worstDay.dailyKD)) K/D"
            }
        }

        // Add top weapon data if available
        if let weapons = stats.weapons, !weapons.isEmpty {
            // Get top 3 weapons by kills
            let topWeapons = weapons.sorted { $0.kills > $1.kills }.prefix(3)

            prompt += """


        TOP WEAPONS (by kills):
        """
            for (index, weapon) in topWeapons.enumerated() {
                prompt += """

        \(index + 1). \(weapon.weaponName) (\(weapon.type))
           - Kills: \(weapon.kills)
           - Accuracy: \(String(format: "%.1f%%", weapon.accuracy))
           - Headshot Rate: \(String(format: "%.1f%%", weapon.headshotPercentage))
           - Kills/Min: \(String(format: "%.2f", weapon.killsPerMinute))
        """
            }
        }

        prompt += """


        Respond in this EXACT JSON format:
        {
            "playstyle": "Name of playstyle (e.g., Aggressive Slayer, Combat Medic)",
            "playstyleDescription": "2-3 sentence description of their playstyle",
            "strengths": ["strength 1", "strength 2", "strength 3"],
            "weaknesses": ["weakness 1", "weakness 2"],
            "tips": [
                {"category": "accuracy|positioning|teamplay|weapons|vehicles|objectives|general", "title": "Short title", "description": "Detailed tip", "priority": "high|medium|low"}
            ],
            "sessionInsight": "Insight about recent performance trend",
            "trendAnalysis": {
                "trajectory": "improving|stable|declining|volatile",
                "consistency": "veryConsistent|consistent|moderate|inconsistent",
                "momentum": "hotStreak|warming|neutral|cooling|slump",
                "peakPerformance": {
                    "bestTimeOfDay": "Morning/Afternoon/Evening/Night or null",
                    "bestDayType": "Weekends/Weekdays or null",
                    "recommendation": "Scheduling recommendation based on patterns"
                },
                "insights": [
                    {"category": "improvement|warning|pattern|recommendation", "title": "Short title", "description": "Detailed insight", "dataPoint": "e.g., +15% or 2.3 hrs"}
                ]
            }
        }

        Provide 3-5 tips. Include trend analysis insights. Be specific and reference actual stats.
        """

        return prompt
    }

    /// Parse LLM response into AICoachResponse
    private func parseLLMResponse(_ response: String, stats: PlayerStats, trendData: TrendDataContainer?) -> AICoachResponse? {
        // Try to extract JSON from the response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            logError("No JSON found in LLM response", category: .error)
            return nil
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            guard let json = json,
                  let playstyle = json["playstyle"] as? String,
                  let playstyleDescription = json["playstyleDescription"] as? String,
                  let strengthsArray = json["strengths"] as? [String],
                  let weaknessesArray = json["weaknesses"] as? [String],
                  let tipsArray = json["tips"] as? [[String: Any]] else {
                logError("Invalid JSON structure in LLM response", category: .error)
                return nil
            }

            // Parse tips
            var tips: [AICoachTip] = []
            for tipJson in tipsArray {
                if let categoryStr = tipJson["category"] as? String,
                   let title = tipJson["title"] as? String,
                   let description = tipJson["description"] as? String,
                   let priorityStr = tipJson["priority"] as? String {

                    let category = parseTipCategory(categoryStr)
                    let priority = parseTipPriority(priorityStr)

                    tips.append(AICoachTip(
                        category: category,
                        title: title,
                        description: description,
                        priority: priority
                    ))
                }
            }

            let sessionInsight = json["sessionInsight"] as? String

            // Parse trend analysis if present
            var trendAnalysis: TrendAnalysis?
            if let trendJson = json["trendAnalysis"] as? [String: Any] {
                trendAnalysis = parseTrendAnalysis(trendJson, stats: stats)
            } else if let data = trendData {
                // Fall back to rule-based trend analysis if LLM didn't provide one
                trendAnalysis = generateRuleBasedTrendAnalysis(trendData: data, stats: stats)
            }

            return AICoachResponse(
                playstyle: playstyle,
                playstyleDescription: playstyleDescription,
                strengths: strengthsArray,
                weaknesses: weaknessesArray,
                tips: tips,
                sessionInsight: sessionInsight,
                trendAnalysis: trendAnalysis,
                generatedAt: Date()
            )

        } catch {
            logError("Failed to parse LLM JSON: \(error.localizedDescription)", category: .error)
            return nil
        }
    }

    /// Parse trend analysis from LLM JSON
    private func parseTrendAnalysis(_ json: [String: Any], stats: PlayerStats) -> TrendAnalysis? {
        guard let trajectoryStr = json["trajectory"] as? String,
              let consistencyStr = json["consistency"] as? String,
              let momentumStr = json["momentum"] as? String else {
            return nil
        }

        let trajectory = parseTrajectory(trajectoryStr)
        let consistency = parseConsistency(consistencyStr)
        let momentum = parseMomentum(momentumStr)

        // Parse peak performance
        var peakPerformance: PeakPerformanceInsight?
        if let peakJson = json["peakPerformance"] as? [String: Any] {
            let bestTimeOfDay = peakJson["bestTimeOfDay"] as? String
            let bestDayType = peakJson["bestDayType"] as? String
            let recommendation = peakJson["recommendation"] as? String ?? "No specific scheduling recommendation."

            if bestTimeOfDay != nil || bestDayType != nil {
                peakPerformance = PeakPerformanceInsight(
                    bestTimeOfDay: bestTimeOfDay,
                    bestDayOfWeek: bestDayType,
                    recommendation: recommendation
                )
            }
        }

        // Parse insights
        var insights: [TrendInsight] = []
        if let insightsArray = json["insights"] as? [[String: Any]] {
            for insightJson in insightsArray {
                if let categoryStr = insightJson["category"] as? String,
                   let title = insightJson["title"] as? String,
                   let description = insightJson["description"] as? String {
                    let category = parseInsightCategory(categoryStr)
                    let dataPoint = insightJson["dataPoint"] as? String

                    insights.append(TrendInsight(
                        category: category,
                        title: title,
                        description: description,
                        dataPoint: dataPoint
                    ))
                }
            }
        }

        // Extract top weapon insight
        let topWeaponInsight = extractTopWeaponInsight(from: stats)

        return TrendAnalysis(
            trajectory: trajectory,
            consistency: consistency,
            peakPerformance: peakPerformance,
            topWeapon: topWeaponInsight,
            sessionLengthImpact: nil,
            momentumStatus: momentum,
            insights: insights
        )
    }

    private func parseTrajectory(_ str: String) -> TrendAnalysis.PerformanceTrajectory {
        switch str.lowercased() {
        case "improving": return .improving
        case "declining": return .declining
        case "volatile": return .volatile
        default: return .stable
        }
    }

    private func parseConsistency(_ str: String) -> TrendAnalysis.ConsistencyRating {
        switch str.lowercased() {
        case "veryconsistent": return .veryConsistent
        case "consistent": return .consistent
        case "inconsistent": return .inconsistent
        default: return .moderate
        }
    }

    private func parseMomentum(_ str: String) -> TrendAnalysis.MomentumStatus {
        switch str.lowercased() {
        case "hotstreak": return .hotStreak
        case "warming": return .warming
        case "cooling": return .cooling
        case "slump": return .slump
        default: return .neutral
        }
    }

    private func parseInsightCategory(_ str: String) -> TrendInsight.InsightCategory {
        switch str.lowercased() {
        case "improvement": return .improvement
        case "warning": return .warning
        case "pattern": return .pattern
        default: return .recommendation
        }
    }

    private func parseTipCategory(_ str: String) -> AICoachTip.TipCategory {
        switch str.lowercased() {
        case "accuracy": return .accuracy
        case "positioning": return .positioning
        case "teamplay": return .teamplay
        case "weapons": return .weapons
        case "vehicles": return .vehicles
        case "objectives": return .objectives
        default: return .general
        }
    }

    private func parseTipPriority(_ str: String) -> AICoachTip.TipPriority {
        switch str.lowercased() {
        case "high": return .high
        case "medium": return .medium
        case "low": return .low
        default: return .medium
        }
    }

    private func determinePlaystyle(stats: PlayerStats) -> (String, String) {
        let kd = stats.kdRatio
        let accuracy = stats.accuracy
        let headshotRate = stats.headshotPercentage
        let revives = stats.revives
        let vehicleKills = stats.vehiclesDestroyed
        let killsPerMatch = stats.killsPerMatch

        // Aggressive Slayer
        if kd > 2.0 && killsPerMatch > 15 {
            return (
                "Aggressive Slayer",
                "You dominate the battlefield with a \(String(format: "%.2f", kd)) K/D and \(String(format: "%.1f", killsPerMatch)) kills per match. Your aggressive playstyle puts constant pressure on the enemy team. Focus on staying alive longer to maximize your impact."
            )
        }

        // Precision Marksman
        if accuracy > 22 && headshotRate > 15 {
            return (
                "Precision Marksman",
                "Your \(String(format: "%.1f%%", accuracy)) accuracy and \(String(format: "%.1f%%", headshotRate)) headshot rate show exceptional aim control. You make every shot count. Consider pushing more aggressively since your gunplay is already elite."
            )
        }

        // Combat Medic
        if Double(revives) > Double(stats.kills) * 0.3 && revives > 100 {
            return (
                "Combat Medic",
                "With \(revives) revives, you're the backbone of your team. Your selfless playstyle keeps squads in the fight. Your team wins more because of you. Don't forget to take fights when you have the advantage."
            )
        }

        // Vehicle Specialist
        if vehicleKills > 150 {
            return (
                "Vehicle Hunter",
                "You've destroyed \(vehicleKills) vehicles - enemy armor trembles when you're on the field. Your anti-vehicle expertise creates space for your infantry. Consider balancing with more infantry combat."
            )
        }

        // Objective Player
        if stats.wlRatio > 55 && kd < 1.5 {
            return (
                "Objective Specialist",
                "Your \(String(format: "%.1f%%", stats.wlRatio)) win rate shows you understand that objectives win games. While your K/D of \(String(format: "%.2f", kd)) could improve, you're focused on what matters most."
            )
        }

        // Balanced Soldier
        return (
            "Balanced Soldier",
            "You're a versatile soldier adapting to whatever your team needs. With a \(String(format: "%.2f", kd)) K/D and \(String(format: "%.1f%%", stats.wlRatio)) win rate, you contribute across multiple roles. Consider specializing to take your game to the next level."
        )
    }

    private func identifyStrengths(stats: PlayerStats) -> [String] {
        var strengths: [String] = []

        if stats.kdRatio >= 1.5 {
            strengths.append("Strong K/D ratio (\(String(format: "%.2f", stats.kdRatio)))")
        }
        if stats.accuracy >= 18 {
            strengths.append("Above average accuracy (\(String(format: "%.1f%%", stats.accuracy)))")
        }
        if stats.headshotPercentage >= 12 {
            strengths.append("Good headshot rate (\(String(format: "%.1f%%", stats.headshotPercentage)))")
        }
        if stats.wlRatio >= 52 {
            strengths.append("Winning player (\(String(format: "%.1f%%", stats.wlRatio)) win rate)")
        }
        if stats.revives >= 100 {
            strengths.append("Strong team support (\(stats.revives) revives)")
        }
        if stats.killsPerMinute >= 1.0 {
            strengths.append("High kill tempo (\(String(format: "%.2f", stats.killsPerMinute)) KPM)")
        }
        if stats.vehiclesDestroyed >= 100 {
            strengths.append("Effective anti-vehicle (\(stats.vehiclesDestroyed) destroyed)")
        }

        // Ensure we have at least one strength
        if strengths.isEmpty {
            if stats.matchesPlayed > 50 {
                strengths.append("Experience (\(stats.matchesPlayed) matches played)")
            } else {
                strengths.append("Learning and improving")
            }
        }

        return Array(strengths.prefix(5))
    }

    private func identifyWeaknesses(stats: PlayerStats) -> [String] {
        var weaknesses: [String] = []

        if stats.kdRatio < 1.0 {
            weaknesses.append("K/D below 1.0 - focus on survival")
        }
        if stats.accuracy < 15 {
            weaknesses.append("Accuracy needs work (\(String(format: "%.1f%%", stats.accuracy)))")
        }
        if stats.headshotPercentage < 10 {
            weaknesses.append("Low headshot rate - aim higher")
        }
        if stats.wlRatio < 45 {
            weaknesses.append("Win rate below average - play objectives")
        }
        if stats.revives < 30 && stats.matchesPlayed > 50 {
            weaknesses.append("Could revive teammates more")
        }
        if stats.killsPerMinute < 0.5 && stats.matchesPlayed > 30 {
            weaknesses.append("Low engagement rate - push more fights")
        }

        return Array(weaknesses.prefix(4))
    }

    private func generateTips(stats: PlayerStats, dailyPerformances: [DailyPerformance]) -> [AICoachTip] {
        var tips: [AICoachTip] = []

        // Accuracy tips
        if stats.accuracy < 12 {
            tips.append(AICoachTip(
                category: .accuracy,
                title: "Master Burst Fire",
                description: "Your \(String(format: "%.1f%%", stats.accuracy)) accuracy suggests full-auto spray. Try burst firing 3-5 rounds at medium range. Reset your aim between bursts for better control.",
                priority: .high
            ))
        } else if stats.accuracy < 18 {
            tips.append(AICoachTip(
                category: .accuracy,
                title: "Pre-aim Common Angles",
                description: "At \(String(format: "%.1f%%", stats.accuracy)) accuracy, you're landing shots but could improve. Keep your crosshair at head level and pre-aim corners where enemies appear.",
                priority: .medium
            ))
        }

        // Headshot tips
        if stats.headshotPercentage < 8 {
            tips.append(AICoachTip(
                category: .accuracy,
                title: "Aim for the Head",
                description: "Only \(String(format: "%.1f%%", stats.headshotPercentage)) of your kills are headshots. Start every engagement aiming at upper chest - recoil will naturally pull to the head.",
                priority: .high
            ))
        } else if stats.headshotPercentage < 15 {
            tips.append(AICoachTip(
                category: .accuracy,
                title: "Headshot Training",
                description: "Your \(String(format: "%.1f%%", stats.headshotPercentage)) headshot rate is decent. Practice tracking heads in close quarters - that's where most gunfights happen.",
                priority: .medium
            ))
        }

        // K/D tips
        if stats.kdRatio < 0.8 {
            tips.append(AICoachTip(
                category: .positioning,
                title: "Choose Your Fights",
                description: "At \(String(format: "%.2f", stats.kdRatio)) K/D, you may be taking unfavorable engagements. Don't challenge enemies who have cover or height advantage. Reposition instead.",
                priority: .high
            ))
        } else if stats.kdRatio < 1.2 {
            tips.append(AICoachTip(
                category: .positioning,
                title: "Use Cover Effectively",
                description: "To improve your \(String(format: "%.2f", stats.kdRatio)) K/D, always fight from cover. Peek, shoot, and return to cover. Never stand in the open during a gunfight.",
                priority: .medium
            ))
        }

        // Teamplay tips
        if stats.revives < 50 && stats.matchesPlayed > 50 {
            tips.append(AICoachTip(
                category: .teamplay,
                title: "Revive More Teammates",
                description: "With only \(stats.revives) revives in \(stats.matchesPlayed) matches, you're missing easy points and team value. Smoke downed allies and revive when safe.",
                priority: .medium
            ))
        }

        if stats.resupplies < 30 && stats.matchesPlayed > 50 {
            tips.append(AICoachTip(
                category: .teamplay,
                title: "Drop Ammo Crates",
                description: "Resupplying teammates is free points and helps your team sustain. Drop ammo near groups of allies, especially snipers and LMG users.",
                priority: .low
            ))
        }

        // Win rate tips
        if stats.wlRatio < 45 {
            tips.append(AICoachTip(
                category: .objectives,
                title: "Play the Objective",
                description: "Your \(String(format: "%.1f%%", stats.wlRatio)) win rate suggests you might be hunting kills instead of objectives. Stay on capture points - kills there count more.",
                priority: .high
            ))
        }

        // Weapon tips based on top weapon (by kills)
        if let topWeapon = stats.weapons?.max(by: { $0.kills < $1.kills }) {
            if topWeapon.accuracy < 15 {
                tips.append(AICoachTip(
                    category: .weapons,
                    title: "Master Your Main Weapon",
                    description: "Your \(topWeapon.weaponName) is at \(String(format: "%.1f%%", topWeapon.accuracy)) accuracy. Spend time in practice range learning its recoil pattern. Muscle memory wins gunfights.",
                    priority: .medium
                ))
            }
        }

        // Session-based tips from daily performances
        if let recentPerformance = dailyPerformances.first {
            if recentPerformance.dailyKD < stats.kdRatio * 0.8 {
                tips.append(AICoachTip(
                    category: .general,
                    title: "Recent Performance Dip",
                    description: "Your recent K/D (\(String(format: "%.2f", recentPerformance.dailyKD))) is below your average (\(String(format: "%.2f", stats.kdRatio))). Consider warming up in a less competitive mode first.",
                    priority: .medium
                ))
            }
        }

        // Sort by priority and limit
        return tips.sorted { $0.priority > $1.priority }.prefix(6).map { $0 }
    }

    private func generateSessionInsight(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot]
    ) -> String? {
        guard !dailyPerformances.isEmpty else { return nil }

        // Calculate recent trend
        let recentKDs = dailyPerformances.prefix(7).map { $0.dailyKD }
        guard recentKDs.count >= 2 else { return nil }

        let firstHalf = Array(recentKDs.prefix(recentKDs.count / 2))
        let secondHalf = Array(recentKDs.suffix(recentKDs.count - recentKDs.count / 2))

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        let trend = ((secondAvg - firstAvg) / max(firstAvg, 0.01)) * 100

        if trend > 10 {
            return "Your performance is trending upward! You've improved by \(String(format: "%.0f%%", abs(trend))) over your recent sessions. Keep doing what you're doing."
        } else if trend < -10 {
            return "Your recent sessions show a \(String(format: "%.0f%%", abs(trend))) dip. This might be fatigue, tougher opponents, or trying new loadouts. Consider taking a break or returning to your comfort picks."
        } else {
            let avgKD = recentKDs.reduce(0, +) / Double(recentKDs.count)
            return "Your performance is stable at around \(String(format: "%.2f", avgKD)) K/D. To break through, focus on one specific skill from the tips above."
        }
    }

    // MARK: - LLM Integration

    /// Generate advice using local LLM (MLX)
    private func generateWithLLM(prompt: String) async -> String? {
        guard let container = modelContainer else {
            logError("Model container not loaded", category: .error)
            return nil
        }

        do {
            logInfo("Starting LLM inference...", category: .general)

            // Create the chat messages for Phi-3 format
            let systemPrompt = """
            You are an expert Battlefield game coach. Analyze player statistics and provide personalized, actionable advice.
            Be encouraging but honest. Focus on specific, practical tips that will help the player improve.
            Keep your response concise and structured.
            """

            let messages: [Message] = [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]

            // Prepare input for generation using messages
            let userInput = UserInput(prompt: .messages(messages))
            let input = try await container.prepare(input: userInput)

            // Set up generation parameters
            let generateParameters = GenerateParameters(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: 0.9,
                repetitionPenalty: 1.1
            )

            // Generate response using the model container
            var generatedText = ""
            let stream = try await container.generate(
                input: input,
                parameters: generateParameters
            )
            
            // Collect the generated text from the stream
            for await generation in stream {
                switch generation {
                case .chunk(let text):
                    generatedText += text
                case .info(let info):
                    logInfo("Generation complete: \(String(format: "%.1f", info.tokensPerSecond)) tokens/sec", category: .general)
                case .toolCall:
                    // Not using tool calls for this use case
                    break
                }
            }

            logSuccess("LLM inference complete", category: .success)
            return generatedText

        } catch {
            logError("LLM generation failed: \(error.localizedDescription)", category: .error)
            return nil
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
