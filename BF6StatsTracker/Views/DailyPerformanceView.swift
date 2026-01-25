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
//  DailyPerformanceView.swift
//  BF6StatsTracker
//
//  View for displaying daily performance statistics
//

import SwiftUI

struct DailyPerformanceView: View {
    @Environment(\.accentColor) private var accentColor
    let dailyPerformance: DailyPerformance
    let yesterdayPerformance: DailyPerformance?
    let showComparison: Bool

    init(dailyPerformance: DailyPerformance, yesterdayPerformance: DailyPerformance? = nil, showComparison: Bool = true) {
        self.dailyPerformance = dailyPerformance
        self.yesterdayPerformance = yesterdayPerformance
        self.showComparison = showComparison
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dailyPerformance.formattedDate)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    HStack(spacing: 8) {
                        if dailyPerformance.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Theme.bf6Green)
                                    .frame(width: 8, height: 8)
                                Text("Active Session")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }

                        Text("Duration: \(dailyPerformance.sessionDurationString)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                Spacer()

                // Session start time
                if let startTime = dailyPerformance.sessionStartTime {
                    Text("Started \(formatTime(startTime))")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)

            // Quick Stats Summary
            HStack(spacing: 12) {
                QuickStatCard(
                    title: "Kills",
                    value: "\(dailyPerformance.deltaKills)",
                    comparison: showComparison ? compareValue(
                        current: dailyPerformance.deltaKills,
                        previous: yesterdayPerformance?.deltaKills
                    ) : nil,
                    icon: "scope",
                    color: Theme.bf6Green
                )

                QuickStatCard(
                    title: "Deaths",
                    value: "\(dailyPerformance.deltaDeaths)",
                    comparison: showComparison ? compareValue(
                        current: dailyPerformance.deltaDeaths,
                        previous: yesterdayPerformance?.deltaDeaths,
                        inverted: true
                    ) : nil,
                    icon: "xmark.circle",
                    color: Theme.bf6Red
                )

                QuickStatCard(
                    title: "K/D",
                    value: String(format: "%.2f", dailyPerformance.dailyKD),
                    comparison: showComparison ? compareKD(
                        current: dailyPerformance.dailyKD,
                        previous: yesterdayPerformance?.dailyKD
                    ) : nil,
                    icon: "chart.line.uptrend.xyaxis",
                    color: accentColor
                )

                QuickStatCard(
                    title: "Matches",
                    value: "\(dailyPerformance.deltaMatchesPlayed)",
                    comparison: nil,
                    icon: "gamecontroller",
                    color: Theme.bf6Blue
                )
            }

            // Combat Performance
            VStack(alignment: .leading, spacing: 12) {
                DailySectionHeader(title: "Combat Performance")

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    DailyStatCard(
                        label: "Headshots",
                        value: "\(dailyPerformance.deltaHeadshots)",
                        percentage: String(format: "%.1f%%", dailyPerformance.dailyHeadshotPercent),
                        icon: "target"
                    )

                    DailyStatCard(
                        label: "Accuracy",
                        value: String(format: "%.1f%%", dailyPerformance.dailyAccuracy),
                        percentage: nil,
                        icon: "scope"
                    )

                    DailyStatCard(
                        label: "KPM",
                        value: String(format: "%.2f", dailyPerformance.dailyKPM),
                        percentage: nil,
                        icon: "timer"
                    )

                    DailyStatCard(
                        label: "Assists",
                        value: "\(dailyPerformance.deltaAssists)",
                        percentage: nil,
                        icon: "person.2"
                    )

                    DailyStatCard(
                        label: "Wins",
                        value: "\(dailyPerformance.deltaWins)",
                        percentage: String(format: "%.0f%%", dailyPerformance.dailyWinRate),
                        icon: "trophy"
                    )

                    DailyStatCard(
                        label: "Score",
                        value: formatScore(dailyPerformance.deltaScore),
                        percentage: nil,
                        icon: "star"
                    )
                }
            }

            // Team Support
            VStack(alignment: .leading, spacing: 12) {
                DailySectionHeader(title: "Team Support")

                HStack(spacing: 12) {
                    TeamStatCard(
                        label: "Revives",
                        value: "\(dailyPerformance.deltaRevives)",
                        icon: "cross.case.fill",
                        color: Theme.bf6Green
                    )

                    TeamStatCard(
                        label: "Resupplies",
                        value: "\(dailyPerformance.deltaResupplies)",
                        icon: "shippingbox.fill",
                        color: accentColor
                    )
                }
            }

            // Yesterday Comparison (if available)
            if showComparison, let yesterday = yesterdayPerformance {
                VStack(alignment: .leading, spacing: 12) {
                    DailySectionHeader(title: "vs Yesterday")

                    HStack(spacing: 16) {
                        ComparisonRow(
                            label: "K/D",
                            current: dailyPerformance.dailyKD,
                            previous: yesterday.dailyKD
                        )

                        Divider()

                        ComparisonRow(
                            label: "Kills",
                            current: Double(dailyPerformance.deltaKills),
                            previous: Double(yesterday.deltaKills)
                        )

                        Divider()

                        ComparisonRow(
                            label: "Win Rate",
                            current: dailyPerformance.dailyWinRate,
                            previous: yesterday.dailyWinRate,
                            isPercentage: true
                        )
                    }
                    .padding()
                    .background(Theme.cardBackground.opacity(0.5))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }

    // MARK: - Helper Functions

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatScore(_ score: Int) -> String {
        if score >= 1000 {
            return String(format: "%.1fk", Double(score) / 1000.0)
        }
        return "\(score)"
    }

    private func compareValue(current: Int, previous: Int?, inverted: Bool = false) -> (String, Color) {
        guard let previous = previous else { return ("", Theme.textSecondary) }

        let diff = current - previous
        if diff == 0 {
            return ("", Theme.textSecondary)
        }

        let isPositive = inverted ? diff < 0 : diff > 0
        let color = isPositive ? Theme.bf6Green : Theme.bf6Red
        let sign = diff > 0 ? "+" : ""

        return ("\(sign)\(diff)", color)
    }

    private func compareKD(current: Double, previous: Double?) -> (String, Color) {
        guard let previous = previous else { return ("", Theme.textSecondary) }

        let diff = current - previous
        if abs(diff) < 0.01 {
            return ("", Theme.textSecondary)
        }

        let color = diff > 0 ? Theme.bf6Green : Theme.bf6Red
        let sign = diff > 0 ? "+" : ""

        return ("\(sign)\(String(format: "%.2f", diff))", color)
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let comparison: (String, Color)?
    let icon: String
    let color: Color

    @State private var animatedValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Text(animatedValue.isEmpty ? value : animatedValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
                .contentTransition(.numericText(value: extractNumericValue(from: value)))

            if let (compText, compColor) = comparison, !compText.isEmpty {
                Text(compText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(compColor)
            } else {
                Text(" ")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(10)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = newValue
            }
        }
    }

    private func extractNumericValue(from string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
        return Double(cleaned) ?? 0
    }
}

struct DailyStatCard: View {
    @Environment(\.accentColor) private var accentColor
    let label: String
    let value: String
    let percentage: String?
    let icon: String

    @State private var animatedValue: String = ""

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(accentColor)

            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Text(animatedValue.isEmpty ? value : animatedValue)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
                .contentTransition(.numericText(value: extractNumericValue(from: value)))

            if let percentage = percentage {
                Text(percentage)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.cardBackground)
        .cornerRadius(10)
        .onAppear {
            animatedValue = value
        }
        .onChange(of: value) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = newValue
            }
        }
    }

    private func extractNumericValue(from string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "%", with: "")
        return Double(cleaned) ?? 0
    }
}

struct TeamStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(10)
    }
}

struct ComparisonRow: View {
    let label: String
    let current: Double
    let previous: Double
    let isPercentage: Bool

    init(label: String, current: Double, previous: Double, isPercentage: Bool = false) {
        self.label = label
        self.current = current
        self.previous = previous
        self.isPercentage = isPercentage
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            let diff = current - previous
            let color = diff > 0 ? Theme.bf6Green : (diff < 0 ? Theme.bf6Red : Theme.textSecondary)
            let sign = diff > 0 ? "+" : ""
            let arrow = diff > 0 ? "↑" : (diff < 0 ? "↓" : "→")

            HStack(spacing: 4) {
                Text(arrow)
                    .font(.caption)
                    .foregroundColor(color)

                if isPercentage {
                    Text("\(sign)\(String(format: "%.0f%%", diff))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                } else {
                    Text("\(sign)\(String(format: "%.2f", diff))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
            }
        }
    }
}

struct DailySectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(Theme.textPrimary)
            .padding(.top, 4)
    }
}

// MARK: - Preview

#Preview {
    // Mock data for preview - in a real scenario this would come from the API
    // For preview purposes, we'll just show the view without actual data
    Text("Preview requires real data from SwiftData")
        .foregroundColor(Theme.textSecondary)
}
