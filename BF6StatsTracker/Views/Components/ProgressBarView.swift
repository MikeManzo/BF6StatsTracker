//
//  ProgressBarView.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI

struct ProgressBarView: View {
    let value: Double // 0.0 to 1.0
    let color: Color
    let height: CGFloat
    let animated: Bool

    init(value: Double, color: Color = .blue, height: CGFloat = 8, animated: Bool = true) {
        self.value = min(max(value, 0), 1)
        self.color = color
        self.height = height
        self.animated = animated
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height)

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(value), height: height)
                    .animation(animated ? .spring(response: 0.6, dampingFraction: 0.8) : .none, value: value)
            }
        }
        .frame(height: height)
    }
}

struct ComparisonProgressBarView: View {
    let todayValue: Double
    let yesterdayValue: Double
    let label: String
    let accentColor: Color

    private var progress: Double {
        guard yesterdayValue > 0 else { return 0 }
        return min(todayValue / yesterdayValue, 1.5) / 1.5 // Cap at 150%
    }

    private var percentChange: Double {
        guard yesterdayValue > 0 else { return 0 }
        return ((todayValue - yesterdayValue) / yesterdayValue) * 100
    }

    private var isImprovement: Bool {
        todayValue > yesterdayValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label and values
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Text("TODAY:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", todayValue))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Image(systemName: isImprovement ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(isImprovement ? .green : .red)

                    Text("YEST:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", yesterdayValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            ProgressBarView(value: progress, color: accentColor, height: 6)

            // Percentage change
            HStack {
                Text(String(format: "%.0f%% %@", abs(percentChange), isImprovement ? "improvement" : "decrease"))
                    .font(.caption2)
                    .foregroundStyle(isImprovement ? .green : .red)

                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBarView(value: 0.7, color: .green, height: 8)
            .frame(width: 300)

        ComparisonProgressBarView(
            todayValue: 24.5,
            yesterdayValue: 22.1,
            label: "🎯 Accuracy",
            accentColor: .orange
        )
        .frame(width: 400)

        ComparisonProgressBarView(
            todayValue: 2.8,
            yesterdayValue: 2.4,
            label: "⚡ KPM",
            accentColor: .blue
        )
        .frame(width: 400)
    }
    .padding()
}
