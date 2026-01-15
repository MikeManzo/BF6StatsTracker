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
//  MiniSparklineView.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI
import Charts

struct MiniSparklineView: View {
    let data: [Double]
    let color: Color
    let showLabels: Bool
    let customLabels: [String]?

    init(data: [Double], color: Color = .blue, showLabels: Bool = false, customLabels: [String]? = nil) {
        self.data = data
        self.color = color
        self.showLabels = showLabels
        self.customLabels = customLabels
    }

    private var labels: [String] {
        if let customLabels = customLabels {
            return customLabels
        }
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let endIndex = min(data.count, days.count)
        return Array(days.suffix(endIndex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Chart
            Chart {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 60)

            // Labels
            if showLabels && !labels.isEmpty {
                HStack {
                    ForEach(labels.indices, id: \.self) { index in
                        Text(labels[index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct SevenDayTrendView: View {
    let dailyPerformances: [DailyPerformance]
    let metric: TrendMetric

    enum TrendMetric {
        case kd
        case kills
        case winRate
        case accuracy

        var title: String {
            switch self {
            case .kd: return "K/D Trend"
            case .kills: return "Kills Trend"
            case .winRate: return "Win Rate"
            case .accuracy: return "Accuracy"
            }
        }

        var color: Color {
            switch self {
            case .kd: return .orange
            case .kills: return .green
            case .winRate: return .blue
            case .accuracy: return .purple
            }
        }

        func value(from performance: DailyPerformance) -> Double {
            switch self {
            case .kd: return performance.dailyKD
            case .kills: return Double(performance.deltaKills)
            case .winRate: return performance.dailyWinRate
            case .accuracy: return performance.dailyAccuracy
            }
        }
    }

    private var chartData: [Double] {
        dailyPerformances.suffix(7).map { metric.value(from: $0) }
    }

    private var dayLabels: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // Short day name (Mon, Tue, etc.)
        return dailyPerformances.suffix(7).map { formatter.string(from: $0.date) }
    }

    private var todayValue: Double {
        guard let today = dailyPerformances.last else { return 0 }
        return metric.value(from: today)
    }

    private var bestDay: String {
        guard let best = dailyPerformances.max(by: { metric.value(from: $0) < metric.value(from: $1) }) else {
            return "N/A"
        }
        return best.formattedDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("📈 \(metric.title)")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text(String(format: metric == .kd ? "%.2f" : "%.1f", todayValue))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(metric.color)
            }

            // Sparkline
            MiniSparklineView(data: chartData, color: metric.color, showLabels: true, customLabels: dayLabels)
                .onAppear {
                    logInfo("SevenDayTrendView - Daily performances count: \(dailyPerformances.count)", category: .api)
                    logInfo("Chart data points: \(chartData.count), values: \(chartData)", category: .api)
                    logInfo("Day labels: \(dayLabels.joined(separator: ", "))", category: .api)
                }

            // Best day
            HStack {
                Text("Best day:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(bestDay)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(metric.color)

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(metric.color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        MiniSparklineView(
            data: [1.2, 1.4, 1.3, 1.6, 1.5, 1.8, 2.1],
            color: .orange,
            showLabels: true
        )
        .frame(width: 400)
        .padding()
    }
}
