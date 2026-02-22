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
//  PlaystyleInsightsView.swift
//  BF6StatsTracker
//
//  Advanced analytics view combining performance heatmap, playstyle fingerprint, and form indicator
//

import SwiftUI
import Charts

struct PlaystyleInsightsView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @State private var selectedPeriod: Int = 30
    @State private var hourlyMetrics: [Int: PerformanceMetrics] = [:]
    @State private var weekdayMetrics: [Int: PerformanceMetrics] = [:]
    @State private var playstyleFingerprint: PlaystyleFingerprint?
    @State private var formIndicator: FormIndicator?
    @State private var recommendations: [String] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    
    let periodOptions = [7, 14, 30, 60, 90]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Playstyle Insights")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Advanced analytics based on your performance history")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Period selector
                    HStack(spacing: 8) {
                        Text("Period:")
                            .foregroundColor(Theme.textSecondary)
                        
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(periodOptions, id: \.self) { days in
                                Text("\(days)d").tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                        .labelsHidden()
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(12)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    HStack(alignment: .top, spacing: 20) {
                        // Form Indicator Section
                        if let form = formIndicator {
                            FormIndicatorCard(form: form, recommendations: recommendations)
                                .frame(maxHeight: .infinity)
                        }
                        
                        // Performance Trends Card
                        PerformanceTrendsCard(period: selectedPeriod)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 380)
                    
                    HStack(alignment: .top, spacing: 20) {
                        // Left column - Performance analysis
                        VStack(spacing: 20) {
                            PerformanceHeatmapCard(
                                hourlyMetrics: hourlyMetrics,
                                weekdayMetrics: weekdayMetrics
                            )
                            
                            SessionLengthAnalysisCard(period: selectedPeriod)
                        }
                        
                        // Right column - Playstyle Fingerprint
                        if let fingerprint = playstyleFingerprint {
                            PlaystyleFingerprintCard(fingerprint: fingerprint)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.backgroundPrimary)
        .onChange(of: selectedPeriod) { _, _ in
            loadData()
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        // Only show loading spinner on initial load
        if !hasLoadedOnce {
            isLoading = true
        }
        
        Task {
            // Load all analytics data
            let hourly = historyManager.getPerformanceByHourOfDay(days: selectedPeriod)
            let weekly = historyManager.getPerformanceByDayOfWeek(days: selectedPeriod)
            let fingerprint = historyManager.getPlaystyleFingerprint(days: selectedPeriod)
            let form = historyManager.getFormIndicator(days: selectedPeriod)
            let recs = historyManager.getRecommendations(days: selectedPeriod)
            
            await MainActor.run {
                self.hourlyMetrics = hourly
                self.weekdayMetrics = weekly
                self.playstyleFingerprint = fingerprint
                self.formIndicator = form
                self.recommendations = recs
                self.isLoading = false
                self.hasLoadedOnce = true
            }
        }
    }
}

// MARK: - Form Indicator Card

struct FormIndicatorCard: View {
    let form: FormIndicator
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: form.status.icon)
                    .font(.title)
                    .foregroundColor(form.status.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Form")
                        .font(.headline)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(form.status.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(form.status.color)
                }
                
                Spacer()
            }
            
            // Performance Comparison Grid
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    StatComparisonColumn(
                        title: "K/D Ratio",
                        recentValue: form.recentKD,
                        overallValue: form.overallKD,
                        format: "%.2f"
                    )
                    
                    Divider()
                        .frame(height: 60)
                    
                    StatComparisonColumn(
                        title: "Win Rate",
                        recentValue: form.recentWinRate,
                        overallValue: form.overallWinRate,
                        format: "%.1f%%"
                    )
                }
                
                Divider()
                
                // Form indicator bar
                HStack(spacing: 8) {
                    Text("Form Rating:")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(form.status.color)
                                .frame(width: geometry.size.width * formRatingPercentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            // Session Stats
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(form.sessionsAnalyzed)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("Improvement")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(improvementText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(improvementColor)
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(Theme.textSecondary)
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }
    
    private var formRatingPercentage: CGFloat {
        switch form.status {
        case .hot: return 1.0
        case .good: return 0.75
        case .neutral: return 0.5
        case .declining: return 0.25
        case .cold: return 0.15
        }
    }
    
    private var improvementText: String {
        let kdDiff = form.recentKD - form.overallKD
        if kdDiff > 0.1 {
            return "+\(String(format: "%.2f", kdDiff))"
        } else if kdDiff < -0.1 {
            return String(format: "%.2f", kdDiff)
        } else {
            return "~"
        }
    }
    
    private var improvementColor: Color {
        let kdDiff = form.recentKD - form.overallKD
        if kdDiff > 0.1 {
            return Theme.bf6Green
        } else if kdDiff < -0.1 {
            return Theme.bf6Red
        } else {
            return Theme.textSecondary
        }
    }
}

struct StatComparisonColumn: View {
    let title: String
    let recentValue: Double
    let overallValue: Double
    let format: String
    
    private var delta: Double {
        recentValue - overallValue
    }
    
    private var deltaColor: Color {
        if delta > 0.01 {
            return Theme.bf6Green
        } else if delta < -0.01 {
            return Theme.bf6Red
        } else {
            return Theme.textSecondary
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("Recent:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: format, recentValue))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
                
                HStack(spacing: 4) {
                    Text("Overall:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: format, overallValue))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus")
                        .font(.caption2)
                    Text(String(format: format, abs(delta)))
                        .font(.caption)
                }
                .foregroundColor(deltaColor)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Performance Heatmap Card

struct PerformanceHeatmapCard: View {
    let hourlyMetrics: [Int: PerformanceMetrics]
    let weekdayMetrics: [Int: PerformanceMetrics]
    @State private var selectedView: HeatmapView = .hourly
    
    enum HeatmapView {
        case hourly
        case weekly
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Performance Heatmap")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Picker("View", selection: $selectedView) {
                    Text("By Hour").tag(HeatmapView.hourly)
                    Text("By Day").tag(HeatmapView.weekly)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            if selectedView == .hourly {
                HourlyHeatmap(metrics: hourlyMetrics)
            } else {
                WeeklyHeatmap(metrics: weekdayMetrics)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

struct HourlyHeatmap: View {
    let metrics: [Int: PerformanceMetrics]
    
    private var maxKD: Double {
        metrics.values.map { $0.kdRatio }.max() ?? 1.0
    }
    
    private var minKD: Double {
        metrics.values.map { $0.kdRatio }.min() ?? 0.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("K/D Ratio by Hour of Day")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 12), spacing: 4) {
                ForEach(0..<24, id: \.self) { hour in
                    if let metric = metrics[hour] {
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorForKD(metric.kdRatio))
                                .frame(height: 40)
                                .overlay(
                                    Text(String(format: "%.2f", metric.kdRatio))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                )
                            
                            Text(hourLabel(hour))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    } else {
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 40)
                            
                            Text(hourLabel(hour))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.bf6Red)
                        .frame(width: 20, height: 12)
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow)
                        .frame(width: 20, height: 12)
                    Text("Medium")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.bf6Green)
                        .frame(width: 20, height: 12)
                    Text("High")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }
    
    private func hourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }
    
    private func colorForKD(_ kd: Double) -> Color {
        let normalized = (kd - minKD) / (maxKD - minKD)
        
        if normalized > 0.66 {
            return Theme.bf6Green
        } else if normalized > 0.33 {
            return Color.yellow
        } else {
            return Theme.bf6Red
        }
    }
}

struct WeeklyHeatmap: View {
    let metrics: [Int: PerformanceMetrics]
    
    private var maxKD: Double {
        metrics.values.map { $0.kdRatio }.max() ?? 1.0
    }
    
    private var minKD: Double {
        metrics.values.map { $0.kdRatio }.min() ?? 0.0
    }
    
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("K/D Ratio by Day of Week")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            HStack(spacing: 12) {
                ForEach(1...7, id: \.self) { day in
                    if let metric = metrics[day] {
                        VStack(spacing: 8) {
                            Text(dayNames[day - 1])
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorForKD(metric.kdRatio))
                                .frame(height: 120)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.2f", metric.kdRatio))
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text("K/D")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Divider()
                                            .background(Color.white.opacity(0.5))
                                        
                                        Text(String(format: "%.0f%%", metric.winRate))
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        
                                        Text("Win Rate")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(8)
                                )
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text(dayNames[day - 1])
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                                .frame(maxWidth: .infinity)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 120)
                                .overlay(
                                    Text("No Data")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func colorForKD(_ kd: Double) -> Color {
        let normalized = (kd - minKD) / (maxKD - minKD)
        
        if normalized > 0.66 {
            return Theme.bf6Green
        } else if normalized > 0.33 {
            return Color.yellow
        } else {
            return Theme.bf6Red
        }
    }
}

// MARK: - Playstyle Fingerprint Card

struct PlaystyleFingerprintCard: View {
    let fingerprint: PlaystyleFingerprint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Playstyle Fingerprint")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            Text("Your combat style profile")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            // Radar chart
            RadarChartView(fingerprint: fingerprint)
                .frame(height: 300)
            
            // Values breakdown
            VStack(spacing: 8) {
                ForEach(Array(zip(fingerprint.labels, fingerprint.values)), id: \.0) { label, value in
                    HStack {
                        Text(label)
                            .foregroundColor(Theme.textSecondary)
                        
                        Spacer()
                        
                        ProgressView(value: value, total: 1.0)
                            .frame(width: 100)
                            .tint(Theme.bf6Green)
                        
                        Text(String(format: "%.0f%%", value * 100))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
            }
            
            // Playstyle description
            Divider()
            
            Text(playstyleDescription)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .frame(width: 400)
    }
    
    private var playstyleDescription: String {
        let dominant = fingerprint.values.enumerated().max(by: { $0.element < $1.element })
        
        guard let dominantIndex = dominant?.offset else {
            return "Keep playing to build your playstyle profile."
        }
        
        switch dominantIndex {
        case 0: return "You play an aggressive, high-tempo style focused on racking up kills quickly."
        case 1: return "You're a precision player who values accuracy and making every shot count."
        case 2: return "You're a team player who focuses on supporting squadmates through revives and resupplies."
        case 3: return "You play tactically, prioritizing survival and staying alive over risky plays."
        case 4: return "You're objective-focused, playing to win and securing victories for your team."
        default: return "Your playstyle is well-balanced across multiple areas."
        }
    }
}

// MARK: - Radar Chart

struct RadarChartView: View {
    let fingerprint: PlaystyleFingerprint
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 40
            
            ZStack {
                // Background circles
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    RadarPolygon(sides: 5, scale: scale)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                }
                
                // Data polygon
                RadarPolygon(sides: 5, values: fingerprint.values)
                    .fill(Theme.bf6Green.opacity(0.3))
                    .frame(width: radius * 2, height: radius * 2)
                
                RadarPolygon(sides: 5, values: fingerprint.values)
                    .stroke(Theme.bf6Green, lineWidth: 2)
                    .frame(width: radius * 2, height: radius * 2)
                
                // Axis lines
                ForEach(0..<5) { index in
                    Path { path in
                        path.move(to: center)
                        let angle = Double(index) * (2 * .pi / 5) - .pi / 2
                        let endPoint = CGPoint(
                            x: center.x + cos(angle) * radius,
                            y: center.y + sin(angle) * radius
                        )
                        path.addLine(to: endPoint)
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
                
                // Labels
                ForEach(0..<5) { index in
                    let angle = Double(index) * (2 * .pi / 5) - .pi / 2
                    let labelDistance = radius + 25
                    let labelPoint = CGPoint(
                        x: center.x + cos(angle) * labelDistance,
                        y: center.y + sin(angle) * labelDistance
                    )
                    
                    Text(fingerprint.labels[index])
                        .font(.caption)
                        .foregroundColor(Theme.textPrimary)
                        .position(labelPoint)
                }
            }
        }
    }
}

struct RadarPolygon: Shape {
    let sides: Int
    var values: [Double]?
    var scale: Double = 1.0
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        var path = Path()
        
        for i in 0..<sides {
            let angle = Double(i) * (2 * .pi / Double(sides)) - .pi / 2
            let value = values?[safe: i] ?? 1.0
            let distance = radius * (values != nil ? value : scale)
            
            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.closeSubpath()
        return path
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
// MARK: - Performance Trends Card

struct PerformanceTrendsCard: View {
    @EnvironmentObject var historyManager: HistoryManager
    let period: Int
    
    @State private var recentSnapshots: [StatsSnapshot] = []
    @State private var kdTrend: [Double] = []
    @State private var winRateTrend: [Double] = []
    @State private var kpmTrend: [Double] = []
    @State private var accuracyTrend: [Double] = []
    @State private var headshotTrend: [Double] = []
    @State private var spmTrend: [Double] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Performance Trends")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            
            Text("Recent session trends over last \(period) days")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            
            if recentSnapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    
                    Text("Not enough data")
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                VStack(spacing: 16) {
                    // K/D Trend
                    TrendRow(
                        title: "K/D Ratio",
                        icon: "scope",
                        current: kdTrend.last ?? 0,
                        trend: kdTrend,
                        format: "%.2f",
                        color: Theme.bf6Green
                    )
                    
                    Divider()
                    
                    // Win Rate Trend
                    TrendRow(
                        title: "Win Rate",
                        icon: "trophy.fill",
                        current: winRateTrend.last ?? 0,
                        trend: winRateTrend,
                        format: "%.1f%%",
                        color: Theme.bf6Blue
                    )
                    
                    Divider()
                    
                    // KPM Trend
                    TrendRow(
                        title: "Kills/Min",
                        icon: "bolt.fill",
                        current: kpmTrend.last ?? 0,
                        trend: kpmTrend,
                        format: "%.2f",
                        color: Theme.bf6Orange
                    )
                    
                    Divider()
                    
                    // Score Per Minute Trend
                    TrendRow(
                        title: "Score/Min",
                        icon: "star.fill",
                        current: spmTrend.last ?? 0,
                        trend: spmTrend,
                        format: "%.0f",
                        color: .yellow
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .onAppear {
            loadTrends()
        }
        .onChange(of: period) { _, _ in
            loadTrends()
        }
        .onChange(of: historyManager.snapshotVersion) { _, _ in
            loadTrends()
        }
    }
    
    private func loadTrends() {
        print("📊 [PerformanceTrendsCard] Loading trends for period: \(period) days")
        Task {
            let snapshots = await historyManager.getSnapshotsInRange(days: period)
            print("📊 [PerformanceTrendsCard] Loaded \(snapshots.count) snapshots for \(period) days")
            
            guard snapshots.count >= 2 else {
                await MainActor.run {
                    self.recentSnapshots = []
                    self.kdTrend = []
                    self.winRateTrend = []
                    self.kpmTrend = []
                    self.spmTrend = []
                    self.accuracyTrend = []
                    self.headshotTrend = []
                }
                return
            }
            
            // Calculate trends from consecutive snapshots
            var kds: [Double] = []
            var winRates: [Double] = []
            var kpms: [Double] = []
            var accuracies: [Double] = []
            var headshots: [Double] = []
            var spms: [Double] = []
            
            for i in 0..<snapshots.count - 1 {
                let current = snapshots[i]
                let next = snapshots[i + 1]
                
                let killsDelta = next.kills - current.kills
                let deathsDelta = next.deaths - current.deaths
                let kd = deathsDelta > 0 ? Double(killsDelta) / Double(deathsDelta) : Double(killsDelta)
                kds.append(kd)
                
                let matchesDelta = next.matchesPlayed - current.matchesPlayed
                let winsDelta = next.wins - current.wins
                let winRate = matchesDelta > 0 ? Double(winsDelta) / Double(matchesDelta) * 100 : 0
                winRates.append(winRate)
                
                let timeDelta = Double(next.timePlayed - current.timePlayed) / 60.0
                let kpm = timeDelta > 0 ? Double(killsDelta) / timeDelta : 0
                kpms.append(kpm)
                
                let scoreDelta = next.totalScore - current.totalScore
                let spm = timeDelta > 0 ? Double(scoreDelta) / timeDelta : 0
                spms.append(spm)
                
                accuracies.append(next.accuracy)
                headshots.append(next.headshotPercentage)
            }
            
            // Limit to max 20 data points, sampling evenly across the period
            let maxPoints = 20
            let kdSlice: ArraySlice<Double>
            let wrSlice: ArraySlice<Double>
            let kpmSlice: ArraySlice<Double>
            let spmSlice: ArraySlice<Double>
            let accSlice: ArraySlice<Double>
            let hsSlice: ArraySlice<Double>
            
            if kds.count <= maxPoints {
                // If we have fewer than maxPoints, use all data
                kdSlice = kds[...]
                wrSlice = winRates[...]
                kpmSlice = kpms[...]
                spmSlice = spms[...]
                accSlice = accuracies[...]
                hsSlice = headshots[...]
            } else {
                // Sample evenly across the entire period
                let step = Double(kds.count) / Double(maxPoints)
                var sampledKds: [Double] = []
                var sampledWRs: [Double] = []
                var sampledKpms: [Double] = []
                var sampledSpms: [Double] = []
                var sampledAccs: [Double] = []
                var sampledHSs: [Double] = []
                
                for i in 0..<maxPoints {
                    let index = min(Int(Double(i) * step), kds.count - 1)
                    sampledKds.append(kds[index])
                    sampledWRs.append(winRates[index])
                    sampledKpms.append(kpms[index])
                    sampledSpms.append(spms[index])
                    sampledAccs.append(accuracies[index])
                    sampledHSs.append(headshots[index])
                }
                
                kdSlice = sampledKds[...]
                wrSlice = sampledWRs[...]
                kpmSlice = sampledKpms[...]
                spmSlice = sampledSpms[...]
                accSlice = sampledAccs[...]
                hsSlice = sampledHSs[...]
            }
            
            await MainActor.run {
                self.recentSnapshots = snapshots
                self.kdTrend = Array(kdSlice)
                self.winRateTrend = Array(wrSlice)
                self.kpmTrend = Array(kpmSlice)
                self.spmTrend = Array(spmSlice)
                self.accuracyTrend = Array(accSlice)
                self.headshotTrend = Array(hsSlice)
                print("📊 [PerformanceTrendsCard] Updated trends - K/D points: \(self.kdTrend.count), first: \(self.kdTrend.first ?? 0), last: \(self.kdTrend.last ?? 0)")
            }
        }
    }
}

struct TrendRow: View {
    let title: String
    let icon: String
    let current: Double
    let trend: [Double]
    let format: String
    let color: Color
    
    private var trendDirection: String {
        guard trend.count >= 2 else { return "arrow.right" }
        let recent = Array(trend.suffix(5))
        let avg = recent.reduce(0, +) / Double(recent.count)
        let previous = Array(trend.dropLast(5).suffix(5))
        let prevAvg = previous.isEmpty ? avg : previous.reduce(0, +) / Double(previous.count)
        
        if avg > prevAvg * 1.05 {
            return "arrow.up.right"
        } else if avg < prevAvg * 0.95 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }
    
    private var trendColor: Color {
        guard trend.count >= 2 else { return Theme.textSecondary }
        let recent = Array(trend.suffix(5))
        let avg = recent.reduce(0, +) / Double(recent.count)
        let previous = Array(trend.dropLast(5).suffix(5))
        let prevAvg = previous.isEmpty ? avg : previous.reduce(0, +) / Double(previous.count)
        
        if avg > prevAvg * 1.05 {
            return Theme.bf6Green
        } else if avg < prevAvg * 0.95 {
            return Theme.bf6Red
        } else {
            return Theme.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                
                Text(String(format: format, current))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Spacer()
            
            // Mini sparkline
            if !trend.isEmpty {
                MiniSparkline(data: trend, color: color)
                    .frame(width: 80, height: 30)
            }
            
            Image(systemName: trendDirection)
                .foregroundColor(trendColor)
                .font(.title3)
        }
    }
}

struct MiniSparkline: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.max() ?? 1.0
            let minValue = data.min() ?? 0.0
            let range = maxValue - minValue
            let safeRange = range > 0 ? range : 1.0
            
            Path { path in
                guard !data.isEmpty else { return }
                
                let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedValue = (value - minValue) / safeRange
                    let y = geometry.size.height * (1 - normalizedValue)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

// MARK: - Session Length Analysis Card

struct SessionLengthAnalysisCard: View {
    @EnvironmentObject var historyManager: HistoryManager
    let period: Int
    
    @State private var sessionMetrics: [SessionLengthBucket: PerformanceMetrics] = [:]
    
    enum SessionLengthBucket: String, CaseIterable {
        case veryShort = "< 30m"
        case short = "30-60m"
        case medium = "1-2h"
        case long = "2-3h"
        case veryLong = "> 3h"
        
        var minutes: ClosedRange<Double> {
            switch self {
            case .veryShort: return 0...30
            case .short: return 30...60
            case .medium: return 60...120
            case .long: return 120...180
            case .veryLong: return 180...10000
            }
        }
        
        var color: Color {
            switch self {
            case .veryShort: return Theme.bf6Red
            case .short: return Theme.bf6Orange
            case .medium: return Theme.bf6Green
            case .long: return Theme.bf6Blue
            case .veryLong: return .purple
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Session Length Analysis")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text("Performance by session duration")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            if sessionMetrics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    
                    Text("Not enough session data")
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 8) {
                    ForEach(SessionLengthBucket.allCases, id: \.self) { bucket in
                        if let metrics = sessionMetrics[bucket], metrics.sessionCount > 0 {
                            SessionLengthRow(bucket: bucket, metrics: metrics)
                        }
                    }
                }
                
                Divider()
                
                // Insight
                if let bestBucket = sessionMetrics.max(by: { $0.value.kdRatio < $1.value.kdRatio })?.key {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        
                        Text("You perform best in \(bestBucket.rawValue) sessions")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .onAppear {
            loadSessionMetrics()
        }
        .onChange(of: period) { _, _ in
            loadSessionMetrics()
        }
        .onChange(of: historyManager.snapshotVersion) { _, _ in
            loadSessionMetrics()
        }
    }
    
    private func loadSessionMetrics() {
        Task {
            let snapshots = await historyManager.getSnapshotsInRange(days: period)
            
            guard snapshots.count >= 2 else {
                await MainActor.run {
                    self.sessionMetrics = [:]
                }
                return
            }
            
            var bucketData: [SessionLengthBucket: [PerformanceMetrics]] = [:]
            
            // Analyze each session
            for i in 0..<snapshots.count - 1 {
                let current = snapshots[i]
                let next = snapshots[i + 1]
                
                let timeDelta = Double(next.timePlayed - current.timePlayed) / 60.0 // minutes
                let killsDelta = next.kills - current.kills
                let deathsDelta = next.deaths - current.deaths
                let matchesDelta = next.matchesPlayed - current.matchesPlayed
                let winsDelta = next.wins - current.wins
                
                guard timeDelta > 0 else { continue }
                
                // Find bucket
                if let bucket = SessionLengthBucket.allCases.first(where: { $0.minutes.contains(timeDelta) }) {
                    let kd = deathsDelta > 0 ? Double(killsDelta) / Double(deathsDelta) : Double(killsDelta)
                    let winRate = matchesDelta > 0 ? Double(winsDelta) / Double(matchesDelta) * 100 : 0
                    let kpm = Double(killsDelta) / timeDelta
                    
                    let metrics = PerformanceMetrics(
                        kdRatio: kd,
                        winRate: winRate,
                        killsPerMatch: matchesDelta > 0 ? Double(killsDelta) / Double(matchesDelta) : 0,
                        accuracy: next.accuracy,
                        sessionCount: 1
                    )
                    
                    bucketData[bucket, default: []].append(metrics)
                }
            }
            
            // Average metrics for each bucket
            var result: [SessionLengthBucket: PerformanceMetrics] = [:]
            for (bucket, metricsList) in bucketData {
                let avgKD = metricsList.map { $0.kdRatio }.reduce(0, +) / Double(metricsList.count)
                let avgWR = metricsList.map { $0.winRate }.reduce(0, +) / Double(metricsList.count)
                let avgKPM = metricsList.map { $0.killsPerMatch }.reduce(0, +) / Double(metricsList.count)
                let avgAcc = metricsList.map { $0.accuracy }.reduce(0, +) / Double(metricsList.count)
                
                result[bucket] = PerformanceMetrics(
                    kdRatio: avgKD,
                    winRate: avgWR,
                    killsPerMatch: avgKPM,
                    accuracy: avgAcc,
                    sessionCount: metricsList.count
                )
            }
            
            await MainActor.run {
                self.sessionMetrics = result
            }
        }
    }
}

struct SessionLengthRow: View {
    let bucket: SessionLengthAnalysisCard.SessionLengthBucket
    let metrics: PerformanceMetrics
    
    var body: some View {
        HStack(spacing: 12) {
            // Bucket label with color indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(bucket.color)
                    .frame(width: 8, height: 8)
                
                Text(bucket.rawValue)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 60, alignment: .leading)
            }
            
            // Session count
            Text("(\(metrics.sessionCount))")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 40, alignment: .leading)
            
            Spacer()
            
            // K/D
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", metrics.kdRatio))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Text("K/D")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 50)
            
            // Win Rate
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", metrics.winRate))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Text("Win")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(width: 50)
            
            // Performance bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(bucket.color)
                        .frame(width: geometry.size.width * normalizedPerformance, height: 6)
                }
            }
            .frame(width: 60, height: 6)
        }
    }
    
    private var normalizedPerformance: CGFloat {
        // Normalize K/D to 0-1 scale (2.0 K/D = 100%)
        let normalized = min(metrics.kdRatio / 2.0, 1.0)
        return CGFloat(normalized)
    }
}

