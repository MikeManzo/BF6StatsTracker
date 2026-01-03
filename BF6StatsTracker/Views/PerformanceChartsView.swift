//
//  PerformanceChartsView.swift
//  BF6StatsTracker
//
//  Advanced charts for performance visualization
//

import SwiftUI
import Charts
import SwiftData

struct PerformanceChartsView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @StateObject private var historyManager = HistoryManager.shared

    // Use @Query to automatically handle object lifecycle
    @Query(sort: \StatsSnapshot.timestamp, order: .reverse)
    private var allSnapshots: [StatsSnapshot]

    @State private var selectedPeriod: ChartPeriod = .week
    @State private var selectedMetric: ChartMetric = .kd

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                header

                // Period selector
                periodSelector

                // Daily Performance Charts
                dailyKDChart

                dailyKillsChart

                // K/D Trend Chart
                kdTrendChart

                // Weapon Usage Pie Chart
                weaponUsageChart

                // Performance Heatmap (Time of day)
                timeOfDayHeatmap

                // Stat comparison radar (if we have snapshots)
                if !allSnapshots.isEmpty {
                    performanceRadar
                }
            }
            .padding()
        }
        .background(Theme.backgroundPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.xyaxis.line")
                .foregroundColor(.purple)
                .font(.title2)

            Text("Performance Analytics")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 12) {
            ForEach(ChartPeriod.allCases) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? Color.purple : Theme.overlayColor)
                        .foregroundColor(selectedPeriod == period ? .black : Theme.textPrimary)
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Daily Performance Charts

    private var dailyKDChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Theme.bf6Green)

                Text("Daily K/D Ratio")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            let dailyData = historyManager.getDailyKDTrend(days: selectedPeriod.days)

            if dailyData.isEmpty {
                Text("No daily performance data available yet")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(dailyData.enumerated()), id: \.offset) { _, data in
                        LineMark(
                            x: .value("Date", data.0),
                            y: .value("K/D", data.1)
                        )
                        .foregroundStyle(Theme.bf6Green.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))

                        AreaMark(
                            x: .value("Date", data.0),
                            y: .value("K/D", data.1)
                        )
                        .foregroundStyle(Theme.bf6Green.opacity(0.2).gradient)
                    }

                    // Average line
                    let avgKD = historyManager.getAverageDailyKD(days: selectedPeriod.days)
                    if avgKD > 0 {
                        RuleMark(y: .value("Average", avgKD))
                            .foregroundStyle(Theme.bf6Orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Avg: \(String(format: "%.2f", avgKD))")
                                    .font(.caption2)
                                    .foregroundColor(Theme.bf6Orange)
                                    .padding(4)
                                    .background(Theme.cardBackground)
                                    .cornerRadius(4)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatDateForChart(date))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private var dailyKillsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Theme.bf6Red)

                Text("Daily Kills")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            let dailyData = historyManager.getDailyKillsTrend(days: selectedPeriod.days)

            if dailyData.isEmpty {
                Text("No daily performance data available yet")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(Array(dailyData.enumerated()), id: \.offset) { _, data in
                        BarMark(
                            x: .value("Date", data.0),
                            y: .value("Kills", data.1)
                        )
                        .foregroundStyle(Theme.bf6Red.gradient)
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatDateForChart(date))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - K/D Trend Chart

    private var kdTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("K/D Trend")
                .font(.headline)

            if allSnapshots.isEmpty {
                noDataView
            } else {
                Chart {
                    ForEach(allSnapshots.prefix(10).reversed(), id: \.id) { snapshot in
                        LineMark(
                            x: .value("Time", snapshot.timestamp),
                            y: .value("K/D", snapshot.kdRatio)
                        )
                        .foregroundStyle(Color.purple.gradient)

                        PointMark(
                            x: .value("Time", snapshot.timestamp),
                            y: .value("K/D", snapshot.kdRatio)
                        )
                        .foregroundStyle(Color.purple)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    // MARK: - Weapon Usage Chart

    private var weaponUsageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weapon Usage")
                .font(.headline)

            if !viewModel.topWeapons.isEmpty {
                Chart(viewModel.topWeapons.prefix(5)) { weapon in
                    SectorMark(
                        angle: .value("Kills", weapon.kills),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Weapon", weapon.weaponName))
                }
                .frame(height: 250)
            } else {
                noDataView
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    // MARK: - Time of Day Heatmap

    private var timeOfDayHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance by Time")
                .font(.headline)

            if allSnapshots.isEmpty {
                noDataView
            } else {
                let hourlyData = calculateHourlyPerformance()

                Chart(hourlyData, id: \.hour) { data in
                    BarMark(
                        x: .value("Hour", data.hour),
                        y: .value("Avg K/D", data.avgKD)
                    )
                    .foregroundStyle(by: .value("Performance", performanceLevel(data.avgKD)))
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    // MARK: - Performance Radar

    private var performanceRadar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Multi-Stat Comparison")
                .font(.headline)

            if let stats = viewModel.playerStats {
                // Simplified radar chart representation
                VStack(spacing: 8) {
                    RadarStatRow(label: "K/D", value: stats.kdRatio, maxValue: 3.0)
                    RadarStatRow(label: "Accuracy", value: stats.accuracy, maxValue: 100)
                    RadarStatRow(label: "Headshot %", value: stats.headshotPercentage, maxValue: 50)
                    RadarStatRow(label: "Win Rate", value: stats.wlRatio, maxValue: 100)
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(16)
    }

    private var noDataView: some View {
        Text("No data available")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private func calculateHourlyPerformance() -> [HourlyData] {
        let calendar = Calendar.current
        var hourlyStats: [Int: (totalKD: Double, count: Int)] = [:]

        for snapshot in allSnapshots {
            let hour = calendar.component(.hour, from: snapshot.timestamp)
            let current = hourlyStats[hour] ?? (0, 0)
            hourlyStats[hour] = (current.totalKD + snapshot.kdRatio, current.count + 1)
        }

        return (0..<24).map { hour in
            let stats = hourlyStats[hour]
            let avgKD = stats != nil ? stats!.totalKD / Double(stats!.count) : 0
            return HourlyData(hour: hour, avgKD: avgKD)
        }
    }

    private func performanceLevel(_ kd: Double) -> String {
        if kd >= 2.0 { return "Excellent" }
        if kd >= 1.5 { return "Good" }
        if kd >= 1.0 { return "Average" }
        return "Below Average"
    }

    private func formatDateForChart(_ date: Date) -> String {
        let formatter = DateFormatter()
        if selectedPeriod == .day {
            formatter.timeStyle = .short
        } else if selectedPeriod == .week {
            formatter.dateFormat = "E"  // Mon, Tue, etc.
        } else {
            formatter.dateFormat = "M/d"  // 12/21
        }
        return formatter.string(from: date)
    }
}

// MARK: - Radar Stat Row

struct RadarStatRow: View {
    let label: String
    let value: Double
    let maxValue: Double

    var percentage: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .fontWeight(.bold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.overlayColor)

                    Rectangle()
                        .fill(Color.purple.gradient)
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
        }
    }
}

// MARK: - Supporting Types

enum ChartPeriod: String, CaseIterable, Identifiable {
    case day = "24h"
    case week = "7d"
    case month = "30d"
    case all = "All"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .all: return 365
        }
    }
}

enum ChartMetric: String, CaseIterable, Identifiable {
    case kd = "K/D"
    case kpm = "Kills/Min"
    case accuracy = "Accuracy"
    case score = "Score"

    var id: String { rawValue }
}

struct HourlyData {
    let hour: Int
    let avgKD: Double
}

// MARK: - Preview

#Preview {
    PerformanceChartsView()
        .environmentObject(StatsViewModel())
}
