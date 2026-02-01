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
//  AICoachAnalysis.swift
//  BF6StatsTracker
//
//  SwiftData model for persisting AI Coach analysis results
//

import Foundation
import SwiftData

/// Persisted AI Coach analysis results
@Model
final class AICoachAnalysis {
    @Attribute(.unique) var id: UUID
    var generatedAt: Date
    var playerName: String

    // Core analysis results
    var playstyle: String
    var playstyleDescription: String
    var strengths: [String]
    var weaknesses: [String]
    var sessionInsight: String?

    // Encoded complex types (tips and trend analysis)
    var tipsData: Data?
    var trendAnalysisData: Data?

    init(
        playerName: String,
        playstyle: String,
        playstyleDescription: String,
        strengths: [String],
        weaknesses: [String],
        sessionInsight: String?,
        tips: [AICoachTip],
        trendAnalysis: TrendAnalysis?,
        generatedAt: Date
    ) {
        self.id = UUID()
        self.generatedAt = generatedAt
        self.playerName = playerName
        self.playstyle = playstyle
        self.playstyleDescription = playstyleDescription
        self.strengths = strengths
        self.weaknesses = weaknesses
        self.sessionInsight = sessionInsight

        // Encode tips
        self.tipsData = try? JSONEncoder().encode(tips.map { CodableAICoachTip(from: $0) })

        // Encode trend analysis
        if let trend = trendAnalysis {
            self.trendAnalysisData = try? JSONEncoder().encode(CodableTrendAnalysis(from: trend))
        }
    }

    /// Create from an AICoachResponse
    convenience init(from response: AICoachResponse, playerName: String) {
        self.init(
            playerName: playerName,
            playstyle: response.playstyle,
            playstyleDescription: response.playstyleDescription,
            strengths: response.strengths,
            weaknesses: response.weaknesses,
            sessionInsight: response.sessionInsight,
            tips: response.tips,
            trendAnalysis: response.trendAnalysis,
            generatedAt: response.generatedAt
        )
    }

    /// Convert back to AICoachResponse
    func toResponse() -> AICoachResponse {
        // Decode tips
        var tips: [AICoachTip] = []
        if let data = tipsData,
           let codableTips = try? JSONDecoder().decode([CodableAICoachTip].self, from: data) {
            tips = codableTips.map { $0.toTip() }
        }

        // Decode trend analysis
        var trendAnalysis: TrendAnalysis?
        if let data = trendAnalysisData,
           let codableTrend = try? JSONDecoder().decode(CodableTrendAnalysis.self, from: data) {
            trendAnalysis = codableTrend.toTrendAnalysis()
        }

        return AICoachResponse(
            playstyle: playstyle,
            playstyleDescription: playstyleDescription,
            strengths: strengths,
            weaknesses: weaknesses,
            tips: tips,
            sessionInsight: sessionInsight,
            trendAnalysis: trendAnalysis,
            generatedAt: generatedAt
        )
    }

    /// Format the generated date for display
    var formattedGeneratedAt: String {
        let now = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(generatedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: generatedAt))"
        } else if calendar.isDateInYesterday(generatedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: generatedAt))"
        } else {
            let days = calendar.dateComponents([.day], from: generatedAt, to: now).day ?? 0
            if days < 7 {
                return "\(days) day\(days == 1 ? "" : "s") ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: generatedAt)
            }
        }
    }
}

// MARK: - Codable Wrapper Types

/// Codable wrapper for AICoachTip
struct CodableAICoachTip: Codable {
    let category: String
    let title: String
    let description: String
    let priority: Int

    init(from tip: AICoachTip) {
        self.category = tip.category.rawValue
        self.title = tip.title
        self.description = tip.description
        self.priority = tip.priority.rawValue
    }

    func toTip() -> AICoachTip {
        let category = AICoachTip.TipCategory(rawValue: self.category) ?? .general
        let priority = AICoachTip.TipPriority(rawValue: self.priority) ?? .medium

        return AICoachTip(
            category: category,
            title: title,
            description: description,
            priority: priority
        )
    }
}

/// Codable wrapper for TrendAnalysis
struct CodableTrendAnalysis: Codable {
    let trajectory: String
    let consistency: String
    let momentumStatus: String
    let peakPerformance: CodablePeakPerformanceInsight?
    let topWeapon: CodableTopWeaponInsight?
    let sessionLengthImpact: String?
    let insights: [CodableTrendInsight]

    init(from trend: TrendAnalysis) {
        self.trajectory = trend.trajectory.rawValue
        self.consistency = trend.consistency.rawValue
        self.momentumStatus = trend.momentumStatus.rawValue
        self.peakPerformance = trend.peakPerformance.map { CodablePeakPerformanceInsight(from: $0) }
        self.topWeapon = trend.topWeapon.map { CodableTopWeaponInsight(from: $0) }
        self.sessionLengthImpact = trend.sessionLengthImpact
        self.insights = trend.insights.map { CodableTrendInsight(from: $0) }
    }

    func toTrendAnalysis() -> TrendAnalysis {
        let trajectory = TrendAnalysis.PerformanceTrajectory(rawValue: self.trajectory) ?? .stable
        let consistency = TrendAnalysis.ConsistencyRating(rawValue: self.consistency) ?? .moderate
        let momentum = TrendAnalysis.MomentumStatus(rawValue: self.momentumStatus) ?? .neutral

        return TrendAnalysis(
            trajectory: trajectory,
            consistency: consistency,
            peakPerformance: peakPerformance?.toPeakPerformanceInsight(),
            topWeapon: topWeapon?.toTopWeaponInsight(),
            sessionLengthImpact: sessionLengthImpact,
            momentumStatus: momentum,
            insights: insights.map { $0.toTrendInsight() }
        )
    }
}

/// Codable wrapper for PeakPerformanceInsight
struct CodablePeakPerformanceInsight: Codable {
    let bestTimeOfDay: String?
    let bestDayOfWeek: String?
    let recommendation: String

    init(from insight: PeakPerformanceInsight) {
        self.bestTimeOfDay = insight.bestTimeOfDay
        self.bestDayOfWeek = insight.bestDayOfWeek
        self.recommendation = insight.recommendation
    }

    func toPeakPerformanceInsight() -> PeakPerformanceInsight {
        PeakPerformanceInsight(
            bestTimeOfDay: bestTimeOfDay,
            bestDayOfWeek: bestDayOfWeek,
            recommendation: recommendation
        )
    }
}

/// Codable wrapper for TopWeaponInsight
struct CodableTopWeaponInsight: Codable {
    let weaponName: String
    let weaponType: String
    let weaponImage: String?
    let kills: Int
    let accuracy: Double
    let headshotPercentage: Double
    let killsPerMinute: Double
    let recommendation: String

    init(from insight: TopWeaponInsight) {
        self.weaponName = insight.weaponName
        self.weaponType = insight.weaponType
        self.weaponImage = insight.weaponImage
        self.kills = insight.kills
        self.accuracy = insight.accuracy
        self.headshotPercentage = insight.headshotPercentage
        self.killsPerMinute = insight.killsPerMinute
        self.recommendation = insight.recommendation
    }

    func toTopWeaponInsight() -> TopWeaponInsight {
        TopWeaponInsight(
            weaponName: weaponName,
            weaponType: weaponType,
            weaponImage: weaponImage,
            kills: kills,
            accuracy: accuracy,
            headshotPercentage: headshotPercentage,
            killsPerMinute: killsPerMinute,
            recommendation: recommendation
        )
    }
}

/// Codable wrapper for TrendInsight
struct CodableTrendInsight: Codable {
    let category: String
    let title: String
    let description: String
    let dataPoint: String?

    init(from insight: TrendInsight) {
        self.category = insight.category.rawValue
        self.title = insight.title
        self.description = insight.description
        self.dataPoint = insight.dataPoint
    }

    func toTrendInsight() -> TrendInsight {
        let category = TrendInsight.InsightCategory(rawValue: self.category) ?? .recommendation

        return TrendInsight(
            category: category,
            title: title,
            description: description,
            dataPoint: dataPoint
        )
    }
}
