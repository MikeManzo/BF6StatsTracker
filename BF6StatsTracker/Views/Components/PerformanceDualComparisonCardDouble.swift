//
//  PerformanceDualComparisonCardDouble.swift
//  BF6StatsTracker
//
//  Dual-stat card component for displaying two related Double metrics side-by-side
//

import SwiftUI

struct PerformanceDualComparisonCardDouble: View {
    let title: String
    let leftLabel: String
    let leftTodayValue: Double
    let leftYesterdayValue: Double
    let rightLabel: String
    let rightTodayValue: Double
    let rightYesterdayValue: Double
    let icon: String
    let accentColor: Color
    let format: String
    var leftYesterdaySummary: Double = 0.0
    var rightYesterdaySummary: Double = 0.0

    @State private var leftDisplayValue: Double = 0
    @State private var rightDisplayValue: Double = 0

    private var leftDelta: Double {
        leftTodayValue - leftYesterdayValue
    }

    private var rightDelta: Double {
        rightTodayValue - rightYesterdayValue
    }

    private var leftPercentChange: Double {
        guard leftYesterdayValue > 0 else { return 0 }
        return (leftDelta / leftYesterdayValue) * 100
    }

    private var rightPercentChange: Double {
        guard rightYesterdayValue > 0 else { return 0 }
        return (rightDelta / rightYesterdayValue) * 100
    }

    private func isImprovement(_ delta: Double) -> Bool {
        // More is always better for K/D and KDA ratios
        return delta > 0.01
    }

    private func changeColor(_ delta: Double) -> Color {
        if abs(delta) < 0.01 { return .secondary }
        return isImprovement(delta) ? .green : .red
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
                // Left stat (K/D)
                VStack(alignment: .leading, spacing: 4) {
                    Text(leftLabel.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: format, leftDisplayValue))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: leftDisplayValue))

                        if leftYesterdayValue > 0 {
                            Image(systemName: leftDelta > 0.01 ? "arrow.up" : leftDelta < -0.01 ? "arrow.down" : "minus")
                                .font(.caption)
                                .foregroundStyle(changeColor(leftDelta))
                        }
                    }

                    if leftYesterdayValue > 0 {
                        Text("\(String(format: "%.0f", abs(leftPercentChange)))%")
                            .font(.caption2)
                            .foregroundStyle(changeColor(leftDelta))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)

                // Right stat (KDA)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rightLabel.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: format, rightDisplayValue))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: rightDisplayValue))

                        if rightYesterdayValue > 0 {
                            Image(systemName: rightDelta > 0.01 ? "arrow.up" : rightDelta < -0.01 ? "arrow.down" : "minus")
                                .font(.caption)
                                .foregroundStyle(changeColor(rightDelta))
                        }
                    }

                    if rightYesterdayValue > 0 {
                        Text("\(String(format: "%.0f", abs(rightPercentChange)))%")
                            .font(.caption2)
                            .foregroundStyle(changeColor(rightDelta))
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
                                    let base = max(0.0001, leftYesterdayValue)
                                    let ratio = max(0.0, min(1.0, leftTodayValue / base))
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
                                    let base = max(0.0001, rightYesterdayValue)
                                    let ratio = max(0.0, min(1.0, rightTodayValue / base))
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

                        Text(String(format: format, leftYesterdayValue))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if leftYesterdayValue > 0 {
                            Text("(\(leftDelta > 0 ? "+" : "")\(String(format: format, leftDelta)))")
                                .font(.caption2)
                                .foregroundStyle(changeColor(leftDelta))
                        }
                    }

                    Spacer()

                    // Right comparison
                    HStack(spacing: 2) {
                        Text(String(format: format, rightYesterdayValue))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if rightYesterdayValue > 0 {
                            Text("(\(rightDelta > 0 ? "+" : "")\(String(format: format, rightDelta)))")
                                .font(.caption2)
                                .foregroundStyle(changeColor(rightDelta))
                        }
                    }
                }

                // Yesterday summary row
                HStack(spacing: 4) {
                    Text("Yesterday: \(String(format: format, leftYesterdaySummary))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: format, rightYesterdaySummary))
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
            leftDisplayValue = leftTodayValue
            rightDisplayValue = rightTodayValue
        }
        .onChange(of: leftTodayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                leftDisplayValue = newValue
            }
        }
        .onChange(of: rightTodayValue) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                rightDisplayValue = newValue
            }
        }
    }
}

#Preview {
    VStack {
        PerformanceDualComparisonCardDouble(
            title: "Ratios",
            leftLabel: "K/D",
            leftTodayValue: 1.61,
            leftYesterdayValue: 1.46,
            rightLabel: "KDA",
            rightTodayValue: 2.15,
            rightYesterdayValue: 1.92,
            icon: "chart.line.uptrend.xyaxis",
            accentColor: .orange,
            format: "%.2f",
            leftYesterdaySummary: 1.53,
            rightYesterdaySummary: 2.07
        )
    }
    .padding()
    .frame(width: 400)
}
