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
//  PerformanceDualComparisonCard.swift
//  BF6StatsTracker
//
//  Dual-stat card component for displaying two related metrics side-by-side
//

import SwiftUI

struct PerformanceDualComparisonCard: View {
    let title: String
    let leftLabel: String
    let leftTodayValue: Int
    let leftYesterdayValue: Int
    let rightLabel: String
    let rightTodayValue: Int
    let rightYesterdayValue: Int
    let icon: String
    let accentColor: Color
    var leftYesterdaySummary: Int = 0
    var rightYesterdaySummary: Int = 0
    var leftLowerIsBetter: Bool = false  // Set to true for stats like Deaths where lower is better
    var rightLowerIsBetter: Bool = false

    @State private var leftDisplayValue: Double = 0
    @State private var rightDisplayValue: Double = 0

    private var leftDelta: Int {
        leftTodayValue - leftYesterdayValue
    }

    private var rightDelta: Int {
        rightTodayValue - rightYesterdayValue
    }

    private var leftPercentChange: Double {
        guard leftYesterdayValue > 0 else { return 0 }
        return (Double(leftDelta) / Double(leftYesterdayValue)) * 100
    }

    private var rightPercentChange: Double {
        guard rightYesterdayValue > 0 else { return 0 }
        return (Double(rightDelta) / Double(rightYesterdayValue)) * 100
    }

    private func isImprovement(_ delta: Int, lowerIsBetter: Bool) -> Bool {
        if lowerIsBetter {
            // For stats like Deaths, fewer is better
            return delta < 0
        } else {
            // For stats like Kills/Assists, more is better
            return delta > 0
        }
    }

    private func changeColor(_ delta: Int, lowerIsBetter: Bool) -> Color {
        if delta == 0 { return .secondary }
        return isImprovement(delta, lowerIsBetter: lowerIsBetter) ? .green : .red
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

            // Two-column layout for stats
            HStack(spacing: 16) {
                // Left stat (Kills)
                VStack(alignment: .leading, spacing: 4) {
                    Text(leftLabel.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(leftDisplayValue))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: leftDisplayValue))

                        if leftYesterdayValue > 0 {
                            Image(systemName: leftDelta > 0 ? "arrow.up" : leftDelta < 0 ? "arrow.down" : "minus")
                                .font(.caption)
                                .foregroundStyle(changeColor(leftDelta, lowerIsBetter: leftLowerIsBetter))
                        }
                    }

                    if leftYesterdayValue > 0 {
                        Text("\(String(format: "%.0f", abs(leftPercentChange)))%")
                            .font(.caption2)
                            .foregroundStyle(changeColor(leftDelta, lowerIsBetter: leftLowerIsBetter))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)

                // Right stat (Assists)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rightLabel.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(rightDisplayValue))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: rightDisplayValue))

                        if rightYesterdayValue > 0 {
                            Image(systemName: rightDelta > 0 ? "arrow.up" : rightDelta < 0 ? "arrow.down" : "minus")
                                .font(.caption)
                                .foregroundStyle(changeColor(rightDelta, lowerIsBetter: rightLowerIsBetter))
                        }
                    }

                    if rightYesterdayValue > 0 {
                        Text("\(String(format: "%.0f", abs(rightPercentChange)))%")
                            .font(.caption2)
                            .foregroundStyle(changeColor(rightDelta, lowerIsBetter: rightLowerIsBetter))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Dual progress bars
            HStack(spacing: 8) {
                // Left progress
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: {
                                    let base = max(1.0, Double(leftYesterdayValue))
                                    let ratio = max(0.0, min(1.0, Double(leftTodayValue) / base))
                                    let w = ratio * Double(geometry.size.width)
                                    let safe = w.isFinite ? w : 0
                                    return CGFloat(safe)
                                }(),
                                height: 4
                            )
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: leftTodayValue)
                    }
                }
                .frame(height: 4)

                // Right progress
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.7), accentColor.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: {
                                    let base = max(1.0, Double(rightYesterdayValue))
                                    let ratio = max(0.0, min(1.0, Double(rightTodayValue) / base))
                                    let w = ratio * Double(geometry.size.width)
                                    let safe = w.isFinite ? w : 0
                                    return CGFloat(safe)
                                }(),
                                height: 4
                            )
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: rightTodayValue)
                    }
                }
                .frame(height: 4)
            }
            .frame(height: 4)

            // Comparison row
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    // Left comparison
                    HStack(spacing: 2) {
                        Text("vs Previous:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("\(leftYesterdayValue)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if leftYesterdayValue > 0 {
                            Text("(\(leftDelta > 0 ? "+" : "")\(leftDelta))")
                                .font(.caption2)
                                .foregroundStyle(changeColor(leftDelta, lowerIsBetter: leftLowerIsBetter))
                        }
                    }

                    Spacer()

                    // Right comparison
                    HStack(spacing: 2) {
                        Text("\(rightYesterdayValue)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if rightYesterdayValue > 0 {
                            Text("(\(rightDelta > 0 ? "+" : "")\(rightDelta))")
                                .font(.caption2)
                                .foregroundStyle(changeColor(rightDelta, lowerIsBetter: rightLowerIsBetter))
                        }
                    }
                }

                // Yesterday summary row
                HStack(spacing: 4) {
                    Text("Yesterday: \(leftYesterdaySummary)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(rightYesterdaySummary)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
            leftDisplayValue = Double(leftTodayValue)
            rightDisplayValue = Double(rightTodayValue)
        }
        .onChange(of: leftTodayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                leftDisplayValue = Double(newValue)
            }
        }
        .onChange(of: rightTodayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                rightDisplayValue = Double(newValue)
            }
        }
    }
}

#Preview {
    VStack {
        PerformanceDualComparisonCard(
            title: "Offense",
            leftLabel: "Kills",
            leftTodayValue: 45,
            leftYesterdayValue: 33,
            rightLabel: "Assists",
            rightTodayValue: 23,
            rightYesterdayValue: 15,
            icon: "target",
            accentColor: .green,
            leftYesterdaySummary: 78,
            rightYesterdaySummary: 42
        )
    }
    .padding()
    .frame(width: 400)
}
