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
//  PerformanceComparisonCard.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI

struct PerformanceComparisonCard: View {
    let title: String
    let todayValue: Int
    let yesterdayValue: Int
    let icon: String
    let accentColor: Color
    var yesterdaySummary: Int = 0

    @State private var displayValue: Double = 0

    private var delta: Int {
        todayValue - yesterdayValue
    }

    private var percentChange: Double {
        guard yesterdayValue > 0 else { return 0 }
        return (Double(delta) / Double(yesterdayValue)) * 100
    }

    private var isImprovement: Bool {
        // For deaths, fewer is better
        if title == "Deaths" {
            return delta < 0
        }
        // For everything else, more is better
        return delta > 0
    }

    private var changeColor: Color {
        if delta == 0 { return .secondary }
        return isImprovement ? .green : .red
    }

    var body: some View {
        VStack(spacing: 12) {
            // Icon and title
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentColor)

                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Today's value (large) with trend indicator
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(displayValue))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: displayValue))

                // Trend arrow and percentage on the main value
                if yesterdayValue > 0 {
                    Image(systemName: delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus")
                        .font(.title3)
                        .foregroundStyle(changeColor)

                    Text("\(String(format: "%.0f", abs(percentChange)))%")
                        .font(.caption)
                        .foregroundStyle(changeColor)
                }

                Spacer()
            }

            // Progress bar
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
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: {
                                let base = max(1.0, Double(yesterdayValue))
                                let ratio = max(0.0, min(1.0, Double(todayValue) / base))
                                let w = ratio * Double(geometry.size.width)
                                let safe = w.isFinite ? w : 0
                                return CGFloat(safe)
                            }(),
                            height: 6
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: todayValue)
                }
            }
            .frame(height: 6)

            // Comparison with previous session
            HStack(spacing: 4) {
                Text("vs Previous:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(yesterdayValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if yesterdayValue > 0 {
                    Text("(\(delta > 0 ? "+" : "")\(delta))")
                        .font(.caption2)
                        .foregroundStyle(changeColor)
                }

                Spacer()

                // Yesterday summary in lower right corner
                Text("Yesterday: \(yesterdaySummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            displayValue = Double(todayValue)
        }
        .onChange(of: todayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                displayValue = Double(newValue)
            }
        }
    }
}

struct PerformanceComparisonCardDouble: View {
    let title: String
    let todayValue: Double
    let yesterdayValue: Double
    let icon: String
    let accentColor: Color
    let format: String
    var yesterdaySummary: Double = 0.0

    @State private var displayValue: Double = 0

    private var delta: Double {
        todayValue - yesterdayValue
    }

    private var percentChange: Double {
        guard yesterdayValue > 0 else { return 0 }
        return (delta / yesterdayValue) * 100
    }

    private var isImprovement: Bool {
        delta > 0
    }

    private var changeColor: Color {
        if abs(delta) < 0.01 { return .secondary }
        return isImprovement ? .green : .red
    }

    var body: some View {
        VStack(spacing: 12) {
            // Icon and title
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentColor)

                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Today's value (large) with trend indicator
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: format, displayValue))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: displayValue))

                // Trend arrow and percentage on the main value
                if yesterdayValue > 0 {
                    Image(systemName: delta > 0.01 ? "arrow.up" : delta < -0.01 ? "arrow.down" : "minus")
                        .font(.title3)
                        .foregroundStyle(changeColor)

                    Text("\(String(format: "%.0f", abs(percentChange)))%")
                        .font(.caption)
                        .foregroundStyle(changeColor)
                }

                Spacer()
            }

            // Progress bar
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
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: {
                                let base = max(0.0001, yesterdayValue)
                                let ratio = max(0.0, min(1.0, todayValue / base))
                                let w = ratio * Double(geometry.size.width)
                                let safe = w.isFinite ? w : 0
                                return CGFloat(safe)
                            }(),
                            height: 6
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: todayValue)
                }
            }
            .frame(height: 6)

            // Comparison with previous session
            HStack(spacing: 4) {
                Text("vs Previous:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(String(format: format, yesterdayValue))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if yesterdayValue > 0 {
                    Text("(\(delta > 0 ? "+" : "")\(String(format: format, delta)))")
                        .font(.caption2)
                        .foregroundStyle(changeColor)
                }

                Spacer()

                // Yesterday summary in lower right corner
                Text("Yesterday: \(String(format: format, yesterdaySummary))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            displayValue = todayValue
        }
        .onChange(of: todayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                displayValue = newValue
            }
        }
    }
}

// Simple card without comparison - just shows today's value and yesterday's summary
struct PerformanceSimpleCard: View {
    let title: String
    let todayValue: Int
    let icon: String
    let accentColor: Color
    var yesterdaySummary: Int = 0

    @State private var displayValue: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            // Icon and title
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentColor)

                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Today's value (large)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(displayValue))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(value: displayValue))

                Spacer()
            }

            // Progress bar (always full since no comparison)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress (full)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: todayValue)
                }
            }
            .frame(height: 6)

            // Yesterday summary only (no comparison)
            HStack(spacing: 4) {
                Spacer()

                // Yesterday summary in lower right corner
                Text("Yesterday: \(yesterdaySummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            displayValue = Double(todayValue)
        }
        .onChange(of: todayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                displayValue = Double(newValue)
            }
        }
    }
}

#Preview {
    VStack {
        PerformanceComparisonCard(
            title: "Kills",
            todayValue: 45,
            yesterdayValue: 33,
            icon: "target",
            accentColor: .green
        )

        PerformanceComparisonCardDouble(
            title: "K/D",
            todayValue: 1.61,
            yesterdayValue: 1.46,
            icon: "chart.line.uptrend.xyaxis",
            accentColor: .orange,
            format: "%.2f"
        )

        PerformanceSimpleCard(
            title: "Matches",
            todayValue: 12,
            icon: "gamecontroller.fill",
            accentColor: .blue,
            yesterdaySummary: 8
        )
    }
    .padding()
    .frame(width: 400)
}
