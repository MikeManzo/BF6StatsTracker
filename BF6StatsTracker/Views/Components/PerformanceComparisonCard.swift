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

            // Today's value (large)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(todayValue)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

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
                            width: min(CGFloat(todayValue) / max(CGFloat(yesterdayValue), 1) * geometry.size.width, geometry.size.width),
                            height: 6
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: todayValue)
                }
            }
            .frame(height: 6)

            // Comparison with yesterday
            HStack(spacing: 4) {
                Image(systemName: delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus")
                    .font(.caption2)
                    .foregroundStyle(changeColor)

                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(changeColor)

                if yesterdayValue > 0 {
                    Text("(\(String(format: "%.0f", abs(percentChange)))%)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("vs \(yesterdayValue)")
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
    }
}

struct PerformanceComparisonCardDouble: View {
    let title: String
    let todayValue: Double
    let yesterdayValue: Double
    let icon: String
    let accentColor: Color
    let format: String

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

            // Today's value (large)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: format, todayValue))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

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
                            width: min(CGFloat(todayValue) / max(CGFloat(yesterdayValue), 0.1) * geometry.size.width, geometry.size.width),
                            height: 6
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: todayValue)
                }
            }
            .frame(height: 6)

            // Comparison with yesterday
            HStack(spacing: 4) {
                Image(systemName: delta > 0.01 ? "arrow.up" : delta < -0.01 ? "arrow.down" : "minus")
                    .font(.caption2)
                    .foregroundStyle(changeColor)

                Text(String(format: format, abs(delta)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(changeColor)

                if yesterdayValue > 0 {
                    Text("(\(String(format: "%.0f", abs(percentChange)))%)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("vs \(String(format: format, yesterdayValue))")
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
    }
    .padding()
    .frame(width: 400)
}
