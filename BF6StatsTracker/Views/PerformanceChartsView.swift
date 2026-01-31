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
//  PerformanceChartsView.swift
//  BF6StatsTracker
//
//  Advanced charts for performance visualization
//

import SwiftUI
import Charts
import SwiftData

struct PerformanceChartsView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @StateObject private var historyManager = HistoryManager.shared

    // Use @Query to automatically handle object lifecycle
    @Query(sort: \StatsSnapshot.timestamp, order: .reverse)
    private var allSnapshots: [StatsSnapshot]

    @State private var selectedPeriod: ChartPeriod = .week
    @State private var selectedMetric: ChartMetric = .kd
    @State private var selectedSnapshot: StatsSnapshot?
    @State private var showingSessionView = false

    // Cached computed data to avoid recalculating on every view update
    @State private var cachedSnapshots: [StatsSnapshot] = []
    @State private var cachedDailyKDTrend: [(Date, Double)] = []
    @State private var cachedDailyKillsTrend: [(Date, Int)] = []
    @State private var cachedRolling7: [(Date, Double)] = []
    @State private var cachedRolling30: [(Date, Double)] = []
    @State private var cachedHourlyData: [HourlyPerformanceData] = []

    /// Number of days of data available based on oldest snapshot
    private var daysOfDataAvailable: Int {
        guard let oldestSnapshot = allSnapshots.last else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: oldestSnapshot.timestamp, to: Date())
        return max(0, components.day ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                header

                // Period selector
                periodSelector

                // Summary Statistics Card
                summaryStatsCard

                // Combined K/D View (Snapshot + Daily)
                combinedKDView

                // Rolling Average Chart
                rollingAverageChart

                // Daily Performance Dashboard with Statistical Context
                enhancedDailyKillsChart

                // Snapshot Kills & Deaths
                snapshotKillsDeathsSection

                // Enhanced Time of Day Heatmap
                enhancedTimeOfDayHeatmap

                // Comparison Metrics
                comparisonMetricsSection

                // Weapon Usage Pie Chart
                weaponUsageChart

                // Stat comparison radar (if we have snapshots)
                if !allSnapshots.isEmpty {
                    performanceRadar
                }
            }
            .padding()
        }
        .background(Theme.backgroundPrimary)
        .animation(.easeInOut(duration: 0.3), value: selectedPeriod)
        .onAppear {
            updateCachedData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            updateCachedData()
        }
        .onChange(of: allSnapshots.count) { _, _ in
            updateCachedData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.xyaxis.line")
                .foregroundColor(Theme.bf6Purple)
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
                let isEnabled = isPeriodEnabled(period)
                Button(action: { selectedPeriod = period }) {
                    Text(period.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? Theme.bf6Purple : Theme.overlayColor)
                        .foregroundColor(selectedPeriod == period ? Theme.selectedText : (isEnabled ? Theme.textPrimary : Theme.textSecondary.opacity(0.5)))
                        .cornerRadius(8)
                        .opacity(isEnabled ? 1.0 : 0.5)
                }
                .disabled(!isEnabled)
            }
        }
    }

    /// Check if a period has enough data to be selectable
    private func isPeriodEnabled(_ period: ChartPeriod) -> Bool {
        switch period {
        case .day, .week, .all:
            return true
        case .month:
            return daysOfDataAvailable >= 30
        }
    }

    // MARK: - Summary Statistics Card

    private var summaryStatsCard: some View {
        let dailyData = cachedDailyKDTrend
        let avgKD = dailyData.isEmpty ? 0.0 : dailyData.map { $0.1 }.reduce(0.0, +) / Double(dailyData.count)
        let stdDev = calculateStdDev(dailyData)
        let bestDay = dailyData.max(by: { $0.1 < $1.1 })
        let worstDay = dailyData.min(by: { $0.1 < $1.1 })
        let trend = calculateTrend(dailyData)

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(Theme.bf6Purple)
                Text("Period Summary")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            HStack(spacing: 20) {
                // Average K/D
                StatBox(
                    title: "Avg K/D",
                    value: String(format: "%.2f", avgKD),
                    subtitle: "±\(String(format: "%.2f", stdDev))",
                    color: Theme.bf6Green
                )

                // Trend
                StatBox(
                    title: "Trend",
                    value: trend.icon,
                    subtitle: trend.description,
                    color: trend.color
                )

                // Best Day
                if let best = bestDay {
                    StatBox(
                        title: "Best Day",
                        value: String(format: "%.2f", best.1),
                        subtitle: formatDate(best.0),
                        color: Theme.bf6Green
                    )
                }

                // Worst Day
                if let worst = worstDay {
                    StatBox(
                        title: "Worst Day",
                        value: String(format: "%.2f", worst.1),
                        subtitle: formatDate(worst.0),
                        color: Theme.bf6Red
                    )
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Combined K/D View (Snapshot + Daily)

    private var combinedKDView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Theme.bf6Green)
                Text("K/D Performance Overview")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            let snapshots = cachedSnapshots
            let dailyData = cachedDailyKDTrend
            let (bestSnapshot, worstSnapshot) = getBestAndWorstFromCache()
            let avgKD = dailyData.isEmpty ? 0.0 : dailyData.map { $0.1 }.reduce(0.0, +) / Double(dailyData.count)

            if snapshots.isEmpty {
                noDataView
            } else {
                VStack(spacing: 16) {
                    // Snapshot-level K/D (Top Panel)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Snapshot History")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        Chart {
                            ForEach(snapshots, id: \.id) { snapshot in
                                LineMark(
                                    x: .value("Time", snapshot.timestamp),
                                    y: .value("K/D", snapshot.kdRatio)
                                )
                                .foregroundStyle(Theme.bf6Green.gradient)
                                .lineStyle(StrokeStyle(lineWidth: 2))

                                PointMark(
                                    x: .value("Time", snapshot.timestamp),
                                    y: .value("K/D", snapshot.kdRatio)
                                )
                                .foregroundStyle(
                                    snapshot.id == bestSnapshot?.id ? .green :
                                    snapshot.id == worstSnapshot?.id ? .red :
                                    colorForKD(snapshot.kdRatio, avg: avgKD)
                                )
                                .symbolSize(snapshot.id == bestSnapshot?.id || snapshot.id == worstSnapshot?.id ? 100 : 40)
                            }

                            // Average line
                            if avgKD > 0 {
                                RuleMark(y: .value("Average", avgKD))
                                    .foregroundStyle(accentColor)
                                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            }
                        }
                        .chartYScale(domain: 0...(snapshots.map { $0.kdRatio }.max() ?? 3.0) * 1.1)
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(formatDateForChart(date))
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                        .chartXAxisLabel("Time", alignment: .center)
                        .chartYAxisLabel("K/D Ratio", alignment: .center)
                        .frame(height: 180)

                        // Legend
                        HStack(spacing: 16) {
                            LegendItem(color: Theme.success, text: "Best")
                            LegendItem(color: Theme.error, text: "Worst")
                            LegendItem(color: accentColor, text: "Average", isDashed: true)
                        }
                        .font(.caption2)
                    }

                    Divider()

                    // Daily Aggregated K/D (Bottom Panel)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Aggregated Performance")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)

                        if dailyData.isEmpty {
                            Text("No daily performance data available yet")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .frame(height: 150)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Chart {
                                ForEach(Array(dailyData.enumerated()), id: \.offset) { _, data in
                                    BarMark(
                                        x: .value("Date", data.0),
                                        y: .value("K/D", data.1)
                                    )
                                    .foregroundStyle(gradientForKD(data.1, avg: avgKD))
                                    .cornerRadius(4)
                                }

                                // Average line
                                if avgKD > 0 {
                                    RuleMark(y: .value("Average", avgKD))
                                        .foregroundStyle(accentColor)
                                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading) { _ in
                                    AxisGridLine()
                                    AxisValueLabel()
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    AxisGridLine()
                                    if let date = value.as(Date.self) {
                                        AxisValueLabel {
                                            Text(formatDateForChart(date))
                                                .font(.caption2)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                }
                            }
                            .chartXAxisLabel("Date", alignment: .center)
                            .chartYAxisLabel("K/D Ratio", alignment: .center)
                            .frame(height: 150)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Rolling Average Chart

    private var rollingAverageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(Theme.info)
                Text("Rolling Averages & Trend")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            let snapshots = cachedSnapshots
            let rolling7 = cachedRolling7
            let rolling30 = cachedRolling30

            if snapshots.isEmpty {
                noDataView
            } else if snapshots.count < 3 {
                Text("Need at least 3 data points for rolling average")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    // Individual snapshots (light background)
                    ForEach(snapshots, id: \.id) { snapshot in
                        PointMark(
                            x: .value("Time", snapshot.timestamp),
                            y: .value("K/D", snapshot.kdRatio)
                        )
                        .foregroundStyle(Theme.textSecondary.opacity(0.3))
                        .symbolSize(20)
                    }

                    // 7-day rolling average
                    ForEach(Array(rolling7.enumerated()), id: \.offset) { _, data in
                        LineMark(
                            x: .value("Date", data.0),
                            y: .value("7-Day Avg", data.1)
                        )
                        .foregroundStyle(Theme.bf6Blue.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    }

                    // 30-day rolling average (if applicable)
                    if !rolling30.isEmpty {
                        ForEach(Array(rolling30.enumerated()), id: \.offset) { _, data in
                            LineMark(
                                x: .value("Date", data.0),
                                y: .value("30-Day Avg", data.1)
                            )
                            .foregroundStyle(Theme.bf6Purple.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 3]))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatDateForChart(date))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxisLabel("Date", alignment: .center)
                .chartYAxisLabel("K/D Ratio", alignment: .center)
                .frame(height: 180)

                // Legend
                HStack(spacing: 16) {
                    LegendItem(color: .gray.opacity(0.3), text: "Individual")
                    LegendItem(color: .blue, text: "7-Day Avg")
                    if !rolling30.isEmpty {
                        LegendItem(color: .purple, text: "30-Day Avg", isDashed: true)
                    }
                }
                .font(.caption2)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Enhanced Daily Kills Chart

    private var enhancedDailyKillsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Theme.bf6Red)
                Text("Daily Kills Performance")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            let dailyData = cachedDailyKillsTrend

            if dailyData.isEmpty {
                noDataView
            } else {
                let avgKills = Double(dailyData.reduce(0) { $0 + $1.1 }) / Double(dailyData.count)
                let maxKills = dailyData.map { $1 }.max() ?? 0

                Chart {
                    ForEach(Array(dailyData.enumerated()), id: \.offset) { _, data in
                        BarMark(
                            x: .value("Date", data.0),
                            y: .value("Kills", data.1)
                        )
                        .foregroundStyle(gradientForKills(data.1, avg: avgKills, max: maxKills))
                        .cornerRadius(4)
                    }

                    // Average line
                    RuleMark(y: .value("Average", avgKills))
                        .foregroundStyle(accentColor)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg: \(Int(avgKills))")
                                .font(.caption2)
                                .foregroundColor(accentColor)
                                .padding(4)
                                .background(Theme.cardBackground)
                                .cornerRadius(4)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatDateForChart(date))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxisLabel("Date", alignment: .center)
                .chartYAxisLabel("Kills", alignment: .center)
                .frame(height: 180)

                // Performance indicators
                HStack(spacing: 12) {
                    SmallStatCard(
                        icon: "arrow.up.circle.fill",
                        label: "Best",
                        value: "\(maxKills)",
                        color: .green
                    )
                    SmallStatCard(
                        icon: "chart.line.flattrend.xyaxis",
                        label: "Average",
                        value: String(format: "%.0f", avgKills),
                        color: .orange
                    )
                    SmallStatCard(
                        icon: "sum",
                        label: "Total",
                        value: "\(dailyData.reduce(0) { $0 + $1.1 })",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Snapshot Kills & Deaths Section

    private var snapshotKillsDeathsSection: some View {
        let snapshots = cachedSnapshots

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.aperture")
                    .foregroundColor(Theme.info)
                Text("Snapshot Delta: Kills vs Deaths")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(snapshots.count) snapshots")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            if snapshots.isEmpty {
                noDataView
            } else {
                // Calculate deltas for each snapshot
                let snapshotDeltas = calculateSnapshotDeltas(snapshots)

                Chart {
                    // Kills series
                    ForEach(snapshotDeltas, id: \.timestamp) { delta in
                        LineMark(
                            x: .value("Time", delta.timestamp),
                            y: .value("Count", delta.deltaKills),
                            series: .value("Type", "Kills")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol {
                            Circle()
                                .fill(Theme.success)
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Deaths series
                    ForEach(snapshotDeltas, id: \.timestamp) { delta in
                        LineMark(
                            x: .value("Time", delta.timestamp),
                            y: .value("Count", delta.deltaDeaths),
                            series: .value("Type", "Deaths")
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 3, dash: [5, 5]))
                        .symbol {
                            Rectangle()
                                .fill(Theme.error)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatDateForChart(date))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxisLabel("Time", alignment: .center)
                .chartYAxisLabel("Count", alignment: .center)
                .chartLegend(position: .top, alignment: .leading) {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Theme.success)
                                .frame(width: 8, height: 8)
                            Text("Kills")
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                        }
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Theme.error)
                                .frame(width: 8, height: 8)
                            Text("Deaths")
                                .font(.caption)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .frame(height: 220)

                // Summary stats
                let totalDeltaKills = snapshotDeltas.reduce(0) { $0 + $1.deltaKills }
                let totalDeltaDeaths = snapshotDeltas.reduce(0) { $0 + $1.deltaDeaths }
                let overallKD = totalDeltaDeaths > 0 ? Double(totalDeltaKills) / Double(totalDeltaDeaths) : Double(totalDeltaKills)

                HStack(spacing: 12) {
                    SmallStatCard(
                        icon: "target",
                        label: "Total Kills",
                        value: "\(totalDeltaKills)",
                        color: .green
                    )
                    SmallStatCard(
                        icon: "xmark.circle",
                        label: "Total Deaths",
                        value: "\(totalDeltaDeaths)",
                        color: .red
                    )
                    SmallStatCard(
                        icon: "chart.bar",
                        label: "K/D Ratio",
                        value: String(format: "%.2f", overallKD),
                        color: overallKD >= 1.0 ? .green : .red
                    )
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private func calculateSnapshotDeltas(_ snapshots: [StatsSnapshot]) -> [(timestamp: Date, deltaKills: Int, deltaDeaths: Int)] {
        guard !snapshots.isEmpty else { return [] }

        let sorted = snapshots.sorted(by: { $0.timestamp < $1.timestamp })
        var deltas: [(Date, Int, Int)] = []

        // First snapshot has 0 delta
        deltas.append((sorted[0].timestamp, 0, 0))

        // Calculate deltas from previous snapshot
        for i in 1..<sorted.count {
            let current = sorted[i]
            let previous = sorted[i - 1]

            let deltaKills = max(0, current.kills - previous.kills)
            let deltaDeaths = max(0, current.deaths - previous.deaths)

            deltas.append((current.timestamp, deltaKills, deltaDeaths))
        }

        return deltas
    }

    // MARK: - Enhanced Time of Day Heatmap

    private var enhancedTimeOfDayHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(Theme.warning)
                Text("Performance by Time of Day")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            let snapshots = cachedSnapshots

            if snapshots.isEmpty {
                noDataView
            } else {
                let hourlyData = cachedHourlyData

                // K/D by Hour
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average K/D by Hour")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    Chart(hourlyData.filter { $0.sessionCount > 0 }, id: \.hour) { data in
                        BarMark(
                            x: .value("Hour", data.hour),
                            y: .value("Avg K/D", data.avgKD)
                        )
                        .foregroundStyle(by: .value("Performance", performanceLevel(data.avgKD)))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxisLabel("Hour of Day", alignment: .center)
                    .chartYAxisLabel("Avg K/D", alignment: .center)
                    .frame(height: 120)
                }

                Divider()

                // Kills by Hour
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kills Earned by Hour")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    Chart(hourlyData.filter { $0.sessionCount > 0 }, id: \.hour) { data in
                        BarMark(
                            x: .value("Hour", data.hour),
                            y: .value("Kills", data.totalKills)
                        )
                        .foregroundStyle(Theme.bf6Green.gradient)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxisLabel("Hour of Day", alignment: .center)
                    .chartYAxisLabel("Kills Earned", alignment: .center)
                    .frame(height: 100)
                }

                Divider()

                // Session Count by Hour
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Activity by Hour")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)

                    Chart(hourlyData.filter { $0.sessionCount > 0 }, id: \.hour) { data in
                        BarMark(
                            x: .value("Hour", data.hour),
                            y: .value("Sessions", data.sessionCount)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartXAxisLabel("Hour of Day", alignment: .center)
                    .chartYAxisLabel("Sessions", alignment: .center)
                    .frame(height: 100)
                }

                // Best time of day
                if let bestHour = hourlyData.filter({ $0.sessionCount > 0 }).max(by: { $0.avgKD < $1.avgKD }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(Theme.warning)
                        Text("Peak Performance: \(bestHour.hour):00 - \(bestHour.hour + 1):00 (K/D: \(String(format: "%.2f", bestHour.avgKD)))")
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Comparison Metrics Section

    private var comparisonMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(Theme.bf6Purple)
                Text("Performance Comparisons")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }

            // Weekend vs Weekday
            let (weekendKD, weekdayKD) = historyManager.getWeekendVsWeekdayStats(days: selectedPeriod.days)

            if weekendKD > 0 || weekdayKD > 0 {
                VStack(spacing: 12) {
                    HStack {
                        Text("Weekend vs Weekday")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                    }

                    HStack(spacing: 16) {
                        ComparisonCard(
                            label: "Weekend",
                            value: String(format: "%.2f", weekendKD),
                            color: .purple,
                            isWinner: weekendKD > weekdayKD
                        )

                        Image(systemName: "arrow.left.and.right")
                            .foregroundColor(Theme.textSecondary)

                        ComparisonCard(
                            label: "Weekday",
                            value: String(format: "%.2f", weekdayKD),
                            color: .blue,
                            isWinner: weekdayKD > weekendKD
                        )
                    }

                    let difference = abs(weekendKD - weekdayKD)
                    let percentDiff = weekdayKD > 0 ? (difference / weekdayKD) * 100 : 0
                    Text("\(weekendKD > weekdayKD ? "Weekends" : "Weekdays") perform \(String(format: "%.1f%%", percentDiff)) better")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Week over week (if enough data)
            if selectedPeriod.days >= 14 {
                let thisWeekKD = historyManager.getAverageDailyKD(days: 7)
                let lastWeekKD = calculateLastWeekKD()

                if thisWeekKD > 0 && lastWeekKD > 0 {
                    Divider()

                    VStack(spacing: 12) {
                        HStack {
                            Text("This Week vs Last Week")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                        }

                        HStack(spacing: 16) {
                            ComparisonCard(
                                label: "This Week",
                                value: String(format: "%.2f", thisWeekKD),
                                color: .green,
                                isWinner: thisWeekKD > lastWeekKD
                            )

                            Image(systemName: "arrow.left.and.right")
                                .foregroundColor(Theme.textSecondary)

                            ComparisonCard(
                                label: "Last Week",
                                value: String(format: "%.2f", lastWeekKD),
                                color: .orange,
                                isWinner: lastWeekKD > thisWeekKD
                            )
                        }

                        let change = thisWeekKD - lastWeekKD
                        let percentChange = lastWeekKD > 0 ? (change / lastWeekKD) * 100 : 0
                        HStack {
                            Image(systemName: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundColor(change >= 0 ? .green : .red)
                            Text("\(change >= 0 ? "+" : "")\(String(format: "%.2f", change)) (\(String(format: "%.1f%%", percentChange)))")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Weapon Usage Chart

    private var weaponUsageChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundColor(Theme.warning)
                Text("Weapon Usage")
                    .font(.headline)
                Spacer()
            }

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
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Performance Radar

    private var performanceRadar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(Theme.bf6Purple)
                Text("Multi-Stat Comparison")
                    .font(.headline)
                Spacer()
            }

            if let stats = viewModel.playerStats {
                VStack(spacing: 8) {
                    RadarStatRow(label: "K/D", value: stats.kdRatio, maxValue: 3.0)
                    RadarStatRow(label: "Accuracy", value: stats.accuracy, maxValue: 100)
                    RadarStatRow(label: "Headshot %", value: stats.headshotPercentage, maxValue: 50)
                    RadarStatRow(label: "Win Rate", value: stats.wlRatio, maxValue: 100)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private var noDataView: some View {
        Text("No data available")
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Functions

    private func calculateTrend(_ data: [(Date, Double)]) -> (icon: String, description: String, color: Color) {
        guard data.count >= 2 else { return ("→", "Stable", .gray) }

        let firstHalf = data.prefix(data.count / 2).map { $0.1 }
        let secondHalf = data.suffix(data.count - data.count / 2).map { $0.1 }

        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return ("→", "Stable", .gray) }

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        // Avoid division by zero
        guard firstAvg > 0 else { return ("→", "Stable", .gray) }

        let change = ((secondAvg - firstAvg) / firstAvg) * 100

        if change > 5 {
            return ("↑", "Improving", .green)
        } else if change < -5 {
            return ("↓", "Declining", .red)
        } else {
            return ("→", "Stable", .orange)
        }
    }

    private func colorForKD(_ kd: Double, avg: Double) -> Color {
        if kd >= avg * 1.2 { return .green }
        if kd >= avg * 0.8 { return .yellow }
        return .red
    }

    private func gradientForKD(_ kd: Double, avg: Double) -> LinearGradient {
        let color: Color
        if kd >= avg * 1.2 { color = .green }
        else if kd >= avg * 0.8 { color = .orange }
        else { color = .red }

        return LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom)
    }

    private func gradientForKills(_ kills: Int, avg: Double, max: Int) -> LinearGradient {
        let color: Color
        if Double(kills) >= avg * 1.2 { color = Theme.bf6Green }
        else if Double(kills) >= avg * 0.8 { color = accentColor }
        else { color = Theme.bf6Red }

        return LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .top, endPoint: .bottom)
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
            formatter.dateFormat = "E"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func calculateLastWeekKD() -> Double {
        // Get snapshots from 8-14 days ago
        guard let context = historyManager.modelContext else { return 0.0 }
        let startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let predicate = #Predicate<StatsSnapshot> { snapshot in
            snapshot.timestamp >= startDate && snapshot.timestamp < endDate
        }

        let descriptor = FetchDescriptor<StatsSnapshot>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        guard let snapshots = try? context.fetch(descriptor), !snapshots.isEmpty else { return 0.0 }

        return snapshots.map { $0.kdRatio }.reduce(0.0, +) / Double(snapshots.count)
    }

    // MARK: - Cache Update

    private func updateCachedData() {
        cachedSnapshots = historyManager.getSnapshotsInRange(days: selectedPeriod.days)
        cachedDailyKDTrend = historyManager.getDailyKDTrend(days: selectedPeriod.days)
        cachedDailyKillsTrend = historyManager.getDailyKillsTrend(days: selectedPeriod.days)

        let snapshotCount = cachedSnapshots.count
        cachedRolling7 = historyManager.getRollingKDAverage(days: selectedPeriod.days, windowSize: min(7, snapshotCount))
        cachedRolling30 = selectedPeriod.days >= 30 ? historyManager.getRollingKDAverage(days: selectedPeriod.days, windowSize: min(30, snapshotCount)) : []
        cachedHourlyData = historyManager.getHourlyStats(snapshots: cachedSnapshots)
    }

    private func getBestAndWorstFromCache() -> (best: StatsSnapshot?, worst: StatsSnapshot?) {
        guard !cachedSnapshots.isEmpty else { return (nil, nil) }
        let best = cachedSnapshots.max(by: { $0.kdRatio < $1.kdRatio })
        let worst = cachedSnapshots.min(by: { $0.kdRatio < $1.kdRatio })
        return (best, worst)
    }

    private func calculateStdDev(_ data: [(Date, Double)]) -> Double {
        guard !data.isEmpty else { return 0.0 }
        let values = data.map { $0.1 }
        let avg = values.reduce(0.0, +) / Double(values.count)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0.0, +) / Double(values.count)
        return sqrt(variance)
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.overlayColor)
        .cornerRadius(8)
    }
}

struct SmallStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Theme.overlayColor)
        .cornerRadius(6)
    }
}

struct SessionCard: View {
    let session: [StatsSnapshot]
    let index: Int

    var body: some View {
        let sessionKD = session.isEmpty ? 0.0 : session.map { $0.kdRatio }.reduce(0, +) / Double(session.count)
        let duration = session.count > 1 ? session.last!.timestamp.timeIntervalSince(session.first!.timestamp) : 0
        let kills = session.isEmpty ? 0 : (session.last!.kills - session.first!.kills)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session \(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                Spacer()
                Circle()
                    .fill(sessionKD >= 1.0 ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                    Text("K/D: \(String(format: "%.2f", sessionKD))")
                        .font(.caption2)
                }

                HStack {
                    Image(systemName: "target")
                        .font(.caption2)
                    Text("\(kills) kills")
                        .font(.caption2)
                }

                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatDuration(duration))
                        .font(.caption2)
                }

                HStack {
                    Image(systemName: "camera.aperture")
                        .font(.caption2)
                    Text("\(session.count) snapshots")
                        .font(.caption2)
                }
            }
            .foregroundColor(Theme.textSecondary)
        }
        .padding(12)
        .frame(width: 160)
        .background(Theme.overlayColor)
        .cornerRadius(10)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ComparisonCard: View {
    let label: String
    let value: String
    let color: Color
    let isWinner: Bool

    var body: some View {
        VStack(spacing: 8) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .foregroundColor(Theme.warning)
                    .font(.caption)
            } else {
                Spacer()
                    .frame(height: 16)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isWinner ? color : Color.clear, lineWidth: 2)
        )
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    var isDashed: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if isDashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 16, height: 2)
                    .overlay(
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                            .foregroundColor(color)
                    )
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(text)
                .foregroundColor(Theme.textSecondary)
        }
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
                    .foregroundColor(Theme.textSecondary)

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

struct HourlyPerformanceData {
    let hour: Int
    let avgKD: Double
    let totalKills: Int
    let sessionCount: Int
}

// MARK: - Preview

#Preview {
    PerformanceChartsView()
        .environmentObject(StatsViewModel())
}
