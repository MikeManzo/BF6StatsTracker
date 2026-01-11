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
//  LoadoutAnalyzerView.swift
//  BF6StatsTracker
//
//  Enhanced loadout analyzer with detailed weapon and gadget recommendations
//

import SwiftUI
import Charts

struct LoadoutAnalyzerView: View {
    @EnvironmentObject var viewModel: StatsViewModel

    @State private var selectedCategory: LoadoutCategory = .overview
    @State private var showingDetails = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Category selector
            categoryPicker

            // Content based on category
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedCategory {
                    case .overview:
                        overviewContent
                    case .weapons:
                        weaponsContent
                    case .classes:
                        classesContent
                    case .gadgets:
                        gadgetsContent
                    case .insights:
                        insightsContent
                    }
                }
                .padding()
            }
        }
        .background(Theme.backgroundPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.doc.horizontal")
                .foregroundColor(.orange)
                .font(.title2)

            Text("Loadout Analyzer")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            // Overall effectiveness score
            if let stats = viewModel.playerStats {
                VStack(spacing: 2) {
                    Text("\(calculateEffectivenessScore(stats))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(calculateEffectivenessScore(stats)))

                    Text("Effectiveness")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(scoreColor(calculateEffectivenessScore(stats)).opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Theme.overlayColor)
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LoadoutCategory.allCases) { category in
                    Button(action: { withAnimation { selectedCategory = category } }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedCategory == category ? Theme.selectedText : Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? Theme.bf6Orange : Theme.overlayColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Theme.overlayColor)
    }

    // MARK: - Overview Content

    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Best loadout summary
            bestLoadoutCard

            // Performance breakdown
            performanceBreakdownCard

            // Quick recommendations
            quickRecommendationsCard
        }
    }

    private var bestLoadoutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Your Best Loadout")
                    .font(.headline)
            }

            if let bestWeapon = viewModel.topWeapons.first,
               let bestClass = viewModel.topClass {
                VStack(spacing: 16) {
                    // Best class
                    HStack {
                        ClassIconView(
                            className: BF6Class(rawValue: bestClass.className) ?? .assault,
                            size: 50,
                            imageURL: bestClass.image
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(bestClass.className)
                                .font(.title3)
                                .fontWeight(.bold)

                            HStack(spacing: 12) {
                                StatPill(label: "K/D", value: String(format: "%.2f", bestClass.kdRatio), color: .green)
                                StatPill(label: "Kills", value: "\(bestClass.kills)", color: .red)
                                StatPill(label: "Time", value: "\(bestClass.timePlayed / 3600)h", color: .blue)
                            }
                        }

                        Spacer()
                    }

                    Divider()

                    // Best weapon
                    HStack {
                        AsyncGameImage(
                            url: URL(string: bestWeapon.image),
                            placeholder: Image(systemName: "scope")
                        )
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(bestWeapon.weaponName)
                                .font(.headline)

                            Text(bestWeapon.type)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 12) {
                                StatPill(label: "Kills", value: "\(bestWeapon.kills)", color: .red)
                                StatPill(label: "K/Min", value: String(format: "%.2f", bestWeapon.killsPerMinute), color: .orange)
                                StatPill(label: "Acc", value: String(format: "%.0f%%", bestWeapon.accuracy), color: .cyan)
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }

    private var performanceBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Breakdown")
                .font(.headline)

            if let stats = viewModel.playerStats {
                VStack(spacing: 12) {
                    PerformanceBar(label: "Combat Efficiency", value: min(stats.kdRatio / 3.0, 1.0), color: .red)
                    PerformanceBar(label: "Accuracy", value: stats.accuracy / 100.0, color: .blue)
                    PerformanceBar(label: "Headshot Rate", value: stats.headshotPercentage / 50.0, color: .yellow)
                    PerformanceBar(label: "Win Rate", value: stats.wlRatio / 100.0, color: .green)
                    PerformanceBar(label: "Team Support", value: Double(stats.revives + stats.resupplies) / 1000.0, color: .purple)
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    private var quickRecommendationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Quick Tips")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                if let stats = viewModel.playerStats {
                    RecommendationRow(
                        icon: "target",
                        text: getAccuracyRecommendation(stats),
                        priority: stats.accuracy < 15 ? .high : .medium
                    )

                    RecommendationRow(
                        icon: "scope",
                        text: getHeadshotRecommendation(stats),
                        priority: stats.headshotPercentage < 10 ? .high : .low
                    )

                    RecommendationRow(
                        icon: "person.2.fill",
                        text: getTeamplayRecommendation(stats),
                        priority: stats.revives < 50 ? .medium : .low
                    )
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    // MARK: - Weapons Content

    private var weaponsContent: some View {
        VStack(spacing: 20) {
            // Weapon usage chart
            weaponUsageChart

            // Weapon recommendations
            weaponRecommendationsSection

            // Weapon comparison
            weaponComparisonSection
        }
    }

    private var weaponUsageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weapon Distribution")
                .font(.headline)

            if !viewModel.topWeapons.isEmpty {
                Chart(viewModel.topWeapons.prefix(5)) { weapon in
                    SectorMark(
                        angle: .value("Kills", weapon.kills),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Weapon", weapon.weaponName))
                    .annotation(position: .overlay) {
                        Text("\(weapon.kills)")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                }
                .frame(height: 250)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    private var weaponRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended to Try")
                .font(.headline)

            if let recommendations = getWeaponRecommendations() {
                ForEach(recommendations, id: \.weaponName) { weapon in
                    EnhancedWeaponRecommendationRow(weapon: weapon, reason: getWeaponRecommendationReason(weapon))
                }
            } else {
                Text("Not enough data for recommendations")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    private var weaponComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Weapons Comparison")
                .font(.headline)

            if !viewModel.topWeapons.isEmpty {
                Chart {
                    ForEach(viewModel.topWeapons.prefix(5)) { weapon in
                        BarMark(
                            x: .value("Kills", weapon.kills),
                            y: .value("Weapon", weapon.weaponName)
                        )
                        .foregroundStyle(Color.orange.gradient)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    // MARK: - Classes Content

    private var classesContent: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.classStats.sorted(by: { $0.kills > $1.kills })) { classData in
                EnhancedClassLoadoutCard(classStats: classData, allClasses: viewModel.classStats)
            }
        }
    }

    // MARK: - Gadgets Content

    private var gadgetsContent: some View {
        VStack(spacing: 12) {
            if let gadgets = viewModel.playerStats?.gadgets, !gadgets.isEmpty {
                ForEach(gadgets.sorted(by: { $0.kills > $1.kills }).prefix(10), id: \.gadgetName) { gadget in
                    GadgetPerformanceCard(gadget: gadget)
                }
            } else {
                Text("No gadget data available")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Insights Content

    private var insightsContent: some View {
        VStack(spacing: 20) {
            if let stats = viewModel.playerStats {
                PlaystyleInsightCard(stats: stats)
                StrengthsWeaknessesCard(stats: stats)
                ImprovementRoadmapCard(stats: stats)
            }
        }
    }

    // MARK: - Helper Functions

    private func calculateEffectivenessScore(_ stats: PlayerStats) -> Int {
        let kdScore = min(stats.kdRatio / 3.0 * 30, 30)
        let accScore = stats.accuracy / 100.0 * 20
        let hsScore = stats.headshotPercentage / 50.0 * 20
        let winScore = stats.wlRatio / 100.0 * 20
        let teamScore = min(Double(stats.revives + stats.resupplies) / 500.0 * 10, 10)

        return Int(kdScore + accScore + hsScore + winScore + teamScore)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .cyan }
        if score >= 40 { return .yellow }
        return .orange
    }

    private func getWeaponRecommendations() -> [WeaponStats]? {
        guard let weapons = viewModel.playerStats?.weapons else { return nil }

        return weapons
            .filter { $0.kills > 10 && $0.kills < 500 }
            .sorted { $0.accuracy > $1.accuracy }
            .prefix(3)
            .map { $0 }
    }

    private func getWeaponRecommendationReason(_ weapon: WeaponStats) -> String {
        if weapon.accuracy > 25 {
            return "Exceptional accuracy potential"
        } else if weapon.killsPerMinute > 2.0 {
            return "High kill rate"
        } else if weapon.headshotKills > weapon.kills / 5 {
            return "Good headshot performance"
        } else {
            return "Underutilized with strong stats"
        }
    }

    private func getAccuracyRecommendation(_ stats: PlayerStats) -> String {
        if stats.accuracy < 10 {
            return "Try burst firing and aim for center mass to improve \(String(format: "%.1f%%", stats.accuracy)) accuracy"
        } else if stats.accuracy < 15 {
            return "Good baseline! Practice controlled bursts to push past \(String(format: "%.1f%%", stats.accuracy))"
        } else {
            return "Excellent \(String(format: "%.1f%%", stats.accuracy)) accuracy! Focus on headshots now"
        }
    }

    private func getHeadshotRecommendation(_ stats: PlayerStats) -> String {
        if stats.headshotPercentage < 5 {
            return "Aim higher! \(String(format: "%.1f%%", stats.headshotPercentage)) HS rate - target upper chest/head"
        } else if stats.headshotPercentage < 15 {
            return "Decent \(String(format: "%.1f%%", stats.headshotPercentage)) HS rate - keep aiming for the head"
        } else {
            return "Outstanding \(String(format: "%.1f%%", stats.headshotPercentage)) HS rate! You're a sharpshooter"
        }
    }

    private func getTeamplayRecommendation(_ stats: PlayerStats) -> String {
        let teamScore = stats.revives + stats.resupplies + stats.repairs
        if teamScore < 50 {
            return "Support your team more - only \(teamScore) team actions so far"
        } else if teamScore < 200 {
            return "Good teamplay with \(teamScore) support actions"
        } else {
            return "Excellent team player! \(teamScore) support actions"
        }
    }
}

// MARK: - Supporting Views

struct PerformanceBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.overlayColor)

                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * min(value, 1.0))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

struct RecommendationRow: View {
    let icon: String
    let text: String
    let priority: RecommendationPriority

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(priority.color)
                .font(.title3)
                .frame(width: 30)

            Text(text)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(priority.color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct EnhancedWeaponRecommendationRow: View {
    let weapon: WeaponStats
    let reason: String

    var body: some View {
        HStack(spacing: 12) {
            AsyncGameImage(
                url: URL(string: weapon.image),
                placeholder: Image(systemName: "scope")
            )
            .frame(width: 50, height: 50)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(weapon.weaponName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    StatPill(label: "Acc", value: String(format: "%.0f%%", weapon.accuracy), color: .cyan)
                    StatPill(label: "K/Min", value: String(format: "%.2f", weapon.killsPerMinute), color: .orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
}

struct EnhancedClassLoadoutCard: View {
    let classStats: ClassStats
    let allClasses: [ClassStats]

    var percentile: Int {
        let sorted = allClasses.sorted(by: { $0.kdRatio > $1.kdRatio })
        if let index = sorted.firstIndex(where: { $0.className == classStats.className }) {
            return Int((1.0 - Double(index) / Double(sorted.count)) * 100)
        }
        return 50
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ClassIconView(
                    className: BF6Class(rawValue: classStats.className) ?? .assault,
                    size: 50,
                    imageURL: classStats.image
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(classStats.className)
                            .font(.headline)

                        Text("Top \(percentile)%")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }

                    HStack(spacing: 12) {
                        StatPill(label: "K/D", value: String(format: "%.2f", classStats.kdRatio), color: .green)
                        StatPill(label: "\(classStats.kills) Kills", value: "\(classStats.timePlayed / 3600)h", color: .blue)
                    }
                }

                Spacer()
            }

            // Performance bars
            VStack(spacing: 8) {
                MiniPerformanceBar(label: "Effectiveness", value: min(classStats.kdRatio / 3.0, 1.0), color: .orange)
                MiniPerformanceBar(label: "Experience", value: Double(classStats.timePlayed) / 36000.0, color: .purple)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
}

struct MiniPerformanceBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.overlayColor)

                    Rectangle()
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * min(value, 1.0))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
    }
}

struct GadgetPerformanceCard: View {
    let gadget: GadgetStats

    var body: some View {
        HStack(spacing: 12) {
            AsyncGameImage(
                url: URL(string: gadget.image),
                placeholder: Image(systemName: "wrench.and.screwdriver")
            )
            .frame(width: 50, height: 50)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(gadget.gadgetName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label("\(gadget.kills) kills", systemImage: "target")
                    Label("\(gadget.uses) uses", systemImage: "hand.tap")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", gadget.killsPerMinute))
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("K/Min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
}

struct PlaystyleInsightCard: View {
    let stats: PlayerStats

    var playstyle: String {
        if stats.kdRatio > 2.5 {
            return "Aggressive Slayer"
        } else if stats.revives > stats.kills / 2 {
            return "Team Medic"
        } else if stats.vehiclesDestroyed > 100 {
            return "Vehicle Hunter"
        } else if stats.accuracy > 20 {
            return "Precision Shooter"
        } else {
            return "Balanced Soldier"
        }
    }

    var playstyleDescription: String {
        if stats.kdRatio > 2.5 {
            return "You excel at aggressive combat with a \(String(format: "%.2f", stats.kdRatio)) K/D. Keep dominating!"
        } else if stats.revives > stats.kills / 2 {
            return "You're a valuable team player with \(stats.revives) revives. Your squad appreciates you!"
        } else if stats.vehiclesDestroyed > 100 {
            return "You've destroyed \(stats.vehiclesDestroyed) vehicles. Enemy armor fears you!"
        } else if stats.accuracy > 20 {
            return "Your \(String(format: "%.1f%%", stats.accuracy)) accuracy shows excellent gun control."
        } else {
            return "You're a well-rounded player. Find your specialty to excel!"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.cyan)
                Text("Your Playstyle")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(playstyle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)

                Text(playstyleDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.cyan.opacity(0.1))
        .cornerRadius(16)
    }
}

struct StrengthsWeaknessesCard: View {
    let stats: PlayerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strengths & Weaknesses")
                .font(.headline)

            HStack(spacing: 16) {
                // Strengths
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Strengths")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if stats.kdRatio > 1.5 {
                            Text("• High K/D ratio")
                        }
                        if stats.accuracy > 18 {
                            Text("• Great accuracy")
                        }
                        if stats.headshotPercentage > 12 {
                            Text("• Strong headshot rate")
                        }
                        if stats.revives > 100 {
                            Text("• Excellent teamplay")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Weaknesses
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Focus Areas")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if stats.accuracy < 15 {
                            Text("• Improve accuracy")
                        }
                        if stats.headshotPercentage < 10 {
                            Text("• Aim for headshots")
                        }
                        if stats.revives < 50 {
                            Text("• Revive teammates more")
                        }
                        if stats.wlRatio < 45 {
                            Text("• Focus on objectives")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }
}

struct ImprovementRoadmapCard: View {
    let stats: PlayerStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.purple)
                Text("Improvement Roadmap")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                RoadmapStep(
                    number: 1,
                    title: "Short Term",
                    task: stats.accuracy < 15 ? "Improve accuracy to 15%" : "Maintain current accuracy",
                    completed: stats.accuracy >= 15
                )

                RoadmapStep(
                    number: 2,
                    title: "Medium Term",
                    task: stats.headshotPercentage < 12 ? "Increase headshots to 12%" : "Push headshot rate higher",
                    completed: stats.headshotPercentage >= 12
                )

                RoadmapStep(
                    number: 3,
                    title: "Long Term",
                    task: stats.kdRatio < 2.0 ? "Achieve 2.0 K/D ratio" : "Maintain elite performance",
                    completed: stats.kdRatio >= 2.0
                )
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
}

struct RoadmapStep: View {
    let number: Int
    let title: String
    let task: String
    let completed: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(completed ? Color.green : Theme.borderColor)
                    .frame(width: 30, height: 30)

                if completed {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(Theme.selectedText)
                } else {
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.selectedText)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(completed ? .green : .secondary)

                Text(task)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Types

enum LoadoutCategory: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case weapons = "Weapons"
    case classes = "Classes"
    case gadgets = "Gadgets"
    case insights = "Insights"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.doc.horizontal"
        case .weapons: return "scope"
        case .classes: return "person.3.fill"
        case .gadgets: return "wrench.and.screwdriver.fill"
        case .insights: return "lightbulb.fill"
        }
    }
}

enum RecommendationPriority {
    case high, medium, low

    var color: Color {
        switch self {
        case .high: return Theme.bf6Red
        case .medium: return Theme.bf6Orange
        case .low: return Theme.bf6Green
        }
    }
}

// MARK: - Preview

#Preview {
    LoadoutAnalyzerView()
        .environmentObject(StatsViewModel())
}
