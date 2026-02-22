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
//  EnhancedClassCard.swift
//  BF6StatsTracker
//
//  Enhanced class performance card with trends and detailed stats
//

import SwiftUI

struct EnhancedClassCard: View {
    let classStats: ClassStats
    let overallKPM: Double
    let overallWinRate: Double
    let totalTimePlayed: Int

    // Computed properties
    private var timePlayedHours: Int {
        classStats.timePlayed / 3600
    }

    private var timePlayedPercentage: Double {
        guard totalTimePlayed > 0 else { return 0 }
        return (Double(classStats.timePlayed) / Double(totalTimePlayed)) * 100
    }

    private var isSpecialized: Bool {
        timePlayedPercentage > 50
    }

    private var kpmComparison: Double {
        guard overallKPM > 0 else { return 0 }
        return ((classStats.killsPerMinute - overallKPM) / overallKPM) * 100
    }

    private var kpmPerformance: PerformanceLevel {
        if abs(kpmComparison) < 5 {
            return .average
        } else if kpmComparison > 0 {
            return .aboveAverage
        } else {
            return .belowAverage
        }
    }

    private var kdPerformance: PerformanceLevel {
        if classStats.kdRatio >= 1.5 {
            return .excellent
        } else if classStats.kdRatio >= 1.0 {
            return .aboveAverage
        } else if classStats.kdRatio >= 0.8 {
            return .average
        } else {
            return .belowAverage
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with class name and specialization badge
            HStack(spacing: 8) {
                SectionHeader(title: "Most Played Class", icon: "person.fill")

                Spacer()

                if isSpecialized {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("Specialist")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Theme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.warning.opacity(0.2))
                    .cornerRadius(6)
                }
            }

            // Main class info
            HStack(spacing: 16) {
                // Class Icon
                ClassIconView(
                    className: BF6Class(rawValue: classStats.className) ?? .assault,
                    size: 70,
                    imageURL: classStats.image
                )

                VStack(alignment: .leading, spacing: 6) {
                    // Class name
                    Text(classStats.className)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    // Time played with percentage
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(timePlayedHours)h played")
                            .font(.caption)
                        Text("(\(String(format: "%.0f%%", timePlayedPercentage)) of total)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .foregroundColor(Theme.textSecondary)

                    // Kills
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.caption)
                        Text("\(classStats.kills.formatted()) kills")
                            .font(.caption)
                    }
                    .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // K/D with performance indicator
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(String(format: "%.2f", classStats.kdRatio))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(kdPerformance.color)

                        Image(systemName: kdPerformance.icon)
                            .font(.caption)
                            .foregroundColor(kdPerformance.color)
                    }

                    Text("K/D Ratio")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Divider()
                .background(Theme.borderColor)

            // Performance Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Kills Per Minute with comparison
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.caption2)
                            .foregroundColor(Theme.warning)
                        Text("Kills/Min")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text(String(format: "%.2f", classStats.killsPerMinute))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    // Comparison to overall KPM
                    HStack(spacing: 2) {
                        Image(systemName: kpmPerformance.comparisonIcon)
                            .font(.caption2)
                        Text(String(format: "%.0f%% vs avg", abs(kpmComparison)))
                            .font(.caption2)
                    }
                    .foregroundColor(kpmPerformance.color)
                }

                // Win Rate (calculated from overall stats proportionally)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.warning)
                        Text("Win Rate")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text(String(format: "%.1f%%", overallWinRate))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("overall avg")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }

                // Deaths
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.error)
                        Text("Deaths")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }

                    Text("\(classStats.deaths.formatted())")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)

                    Text("\(String(format: "%.1f", Double(classStats.deaths) / Double(max(1, classStats.kills)))) D/K")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Time Distribution Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Class Focus")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Text("\(String(format: "%.0f%%", timePlayedPercentage))")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isSpecialized ? .yellow : Theme.textPrimary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: isSpecialized ?
                                        [.yellow, .yellow.opacity(0.7)] :
                                        [Theme.bf6Green, Theme.bf6Green.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * min(1.0, timePlayedPercentage / 100.0),
                                height: 6
                            )
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: timePlayedPercentage)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isSpecialized ? Theme.warning.opacity(0.4) : Theme.borderColor,
                    lineWidth: isSpecialized ? 2 : 1
                )
        )
    }
}

// MARK: - Performance Level

enum PerformanceLevel {
    case excellent
    case aboveAverage
    case average
    case belowAverage

    var color: Color {
        switch self {
        case .excellent: return .green
        case .aboveAverage: return Theme.bf6Green
        case .average: return .orange
        case .belowAverage: return .red
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "arrow.up.circle.fill"
        case .aboveAverage: return "arrow.up.circle"
        case .average: return "minus.circle"
        case .belowAverage: return "arrow.down.circle"
        }
    }

    var comparisonIcon: String {
        switch self {
        case .excellent, .aboveAverage: return "arrow.up"
        case .average: return "equal"
        case .belowAverage: return "arrow.down"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Preview data requires actual ClassStats from API")
                .foregroundColor(Theme.textSecondary)
        }
        .padding()
    }
}
