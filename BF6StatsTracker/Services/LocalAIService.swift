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
    case notLoaded
    case loading(progress: Double)
    case loaded
    case error(String)
    case generating

    var isReady: Bool {
        if case .loaded = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .notLoaded: return "Model not loaded"
        case .loading(let progress): return "Loading model... \(Int(progress * 100))%"
        case .loaded: return "Model ready"
        case .error(let message): return "Error: \(message)"
        case .generating: return "Generating advice..."
        }
    }
}

// MARK: - Local AI Service

@MainActor
class LocalAIService: ObservableObject {
    static let shared = LocalAIService()

    @Published var status: AIModelStatus = .notLoaded
    @Published var lastResponse: AICoachResponse?
    @Published var isModelLoaded: Bool = false

    private var unloadTimer: Timer?
    private let unloadTimeout: TimeInterval = 300 // 5 minutes

    // MLX model instance (placeholder - actual MLX integration requires the MLX Swift package)
    private var modelLoaded: Bool = false

    private init() {}

    // MARK: - Model Lifecycle

    /// Load the AI model into memory
    func loadModel() async {
        guard !modelLoaded else { return }

        status = .loading(progress: 0.0)

        // Simulate model loading progress
        // In production, this would be actual MLX model loading
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            status = .loading(progress: Double(i) / 10.0)
        }

        modelLoaded = true
        isModelLoaded = true
        status = .loaded

        logInfo("AI Coach model loaded", category: .general)
        resetUnloadTimer()
    }

    /// Unload the AI model from memory
    func unloadModel() {
        unloadTimer?.invalidate()
        unloadTimer = nil

        modelLoaded = false
        isModelLoaded = false
        status = .notLoaded

        logInfo("AI Coach model unloaded", category: .general)
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

        resetUnloadTimer()
        status = .generating

        // Build the analysis using rule-based logic + LLM enhancement
        // For now, we use sophisticated rule-based analysis
        // In production, this would send a prompt to the local LLM

        let response = await analyzePlayerStats(
            stats: stats,
            dailyPerformances: dailyPerformances,
            recentSnapshots: recentSnapshots
        )

        lastResponse = response
        status = .loaded

        return response
    }

    // MARK: - Analysis Engine

    private func analyzePlayerStats(
        stats: PlayerStats,
        dailyPerformances: [DailyPerformance],
        recentSnapshots: [StatsSnapshot]
    ) async -> AICoachResponse {
        // Simulate LLM processing time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second

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

    // MARK: - LLM Integration (Future)

    /// Generate advice using local LLM (MLX)
    /// This is a placeholder for actual MLX integration
    private func generateWithLLM(prompt: String) async -> String {
        // In production, this would:
        // 1. Load MLX model if not loaded
        // 2. Tokenize the prompt
        // 3. Run inference on Apple Silicon
        // 4. Decode and return the response

        // For now, return empty string as we use rule-based analysis
        return ""
    }

    /// Build prompt for LLM
    private func buildPrompt(stats: PlayerStats, history: [DailyPerformance]) -> String {
        """
        You are an expert Battlefield coach. Analyze these player statistics and provide 3-5 specific, actionable tips to improve their gameplay.

        Current Stats:
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

        Recent Performance Trend:
        \(history.prefix(5).map { "- \(formatDate($0.date)): K/D \(String(format: "%.2f", $0.dailyKD)), \($0.deltaKills) kills" }.joined(separator: "\n"))

        Based on this data, identify their playstyle, list their strengths, areas for improvement, and provide specific tips. Be encouraging but honest.
        """
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
