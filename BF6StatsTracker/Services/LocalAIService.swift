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
    let generatedAt: Date

    static let empty = AICoachResponse(
        playstyle: "Unknown",
        playstyleDescription: "Not enough data to analyze your playstyle.",
        strengths: [],
        weaknesses: [],
        tips: [],
        sessionInsight: nil,
        generatedAt: Date()
    )
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
        recentSnapshots: [StatsSnapshot]
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
            recentSnapshots: recentSnapshots
        )

        lastResponse = response

        // Unload model immediately after analysis to free memory
        unloadModel()

        return response
    }

    // MARK: - Analysis Engine

    private func analyzePlayerStats(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot]
    ) async -> AICoachResponse {
        // Build the prompt for LLM analysis
        let prompt = buildAnalysisPrompt(stats: stats, history: dailyPerformances)

        // Try LLM generation first
        if let llmResponse = await generateWithLLM(prompt: prompt),
           let parsedResponse = parseLLMResponse(llmResponse, stats: stats) {
            logSuccess("Using LLM-generated coaching advice", category: .success)
            return parsedResponse
        }

        // Fallback to rule-based analysis if LLM fails or returns invalid response
        logInfo("Falling back to rule-based analysis", category: .general)
        return generateRuleBasedAnalysis(
            stats: stats,
            dailyPerformances: dailyPerformances,
            recentSnapshots: recentSnapshots
        )
    }

    /// Rule-based fallback analysis
    private func generateRuleBasedAnalysis(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot]
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

        return AICoachResponse(
            playstyle: playstyle,
            playstyleDescription: playstyleDesc,
            strengths: strengths,
            weaknesses: weaknesses,
            tips: tips,
            sessionInsight: sessionInsight,
            generatedAt: Date()
        )
    }

    /// Build a structured prompt for LLM analysis
    private func buildAnalysisPrompt(stats: PlayerStats, history: [DailyPerformance]) -> String {
        """
        Analyze these Battlefield player statistics and provide coaching advice.

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

        Respond in this EXACT JSON format:
        {
            "playstyle": "Name of playstyle (e.g., Aggressive Slayer, Combat Medic)",
            "playstyleDescription": "2-3 sentence description of their playstyle",
            "strengths": ["strength 1", "strength 2", "strength 3"],
            "weaknesses": ["weakness 1", "weakness 2"],
            "tips": [
                {"category": "accuracy|positioning|teamplay|weapons|vehicles|objectives|general", "title": "Short title", "description": "Detailed tip", "priority": "high|medium|low"},
                {"category": "positioning", "title": "Another tip", "description": "Description", "priority": "medium"}
            ],
            "sessionInsight": "Optional insight about recent performance trend"
        }

        Provide 3-5 tips. Be specific and actionable. Reference their actual stats in your advice.
        """
    }

    /// Parse LLM response into AICoachResponse
    private func parseLLMResponse(_ response: String, stats: PlayerStats) -> AICoachResponse? {
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

            return AICoachResponse(
                playstyle: playstyle,
                playstyleDescription: playstyleDescription,
                strengths: strengthsArray,
                weaknesses: weaknessesArray,
                tips: tips,
                sessionInsight: sessionInsight,
                generatedAt: Date()
            )

        } catch {
            logError("Failed to parse LLM JSON: \(error.localizedDescription)", category: .error)
            return nil
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

        // Weapon tips based on top weapon
        if let topWeapon = stats.weapons?.first {
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
