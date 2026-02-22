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
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(periodOptions, id: \.self) { days in
                            Text("\(days)d").tag(days)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(12)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    // Form Indicator Section
                    if let form = formIndicator {
                        FormIndicatorCard(form: form, recommendations: recommendations)
                    }
                    
                    HStack(alignment: .top, spacing: 20) {
                        // Performance Heatmap
                        PerformanceHeatmapCard(
                            hourlyMetrics: hourlyMetrics,
                            weekdayMetrics: weekdayMetrics
                        )
                        
                        // Playstyle Fingerprint
                        if let fingerprint = playstyleFingerprint {
                            PlaystyleFingerprintCard(fingerprint: fingerprint)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.background)
        .onChange(of: selectedPeriod) { _, _ in
            loadData()
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        
        Task {
            // Load all analytics data
            let hourly = await Task.detached {
                await MainActor.run {
                    historyManager.getPerformanceByHourOfDay(days: selectedPeriod)
                }
            }.value
            
            let weekly = await Task.detached {
                await MainActor.run {
                    historyManager.getPerformanceByDayOfWeek(days: selectedPeriod)
                }
            }.value
            
            let fingerprint = await Task.detached {
                await MainActor.run {
                    historyManager.getPlaystyleFingerprint(days: selectedPeriod)
                }
            }.value
            
            let form = await Task.detached {
                await MainActor.run {
                    historyManager.getFormIndicator()
                }
            }.value
            
            let recs = await Task.detached {
                await MainActor.run {
                    historyManager.getRecommendations()
                }
            }.value
            
            await MainActor.run {
                self.hourlyMetrics = hourly
                self.weekdayMetrics = weekly
                self.playstyleFingerprint = fingerprint
                self.formIndicator = form
                self.recommendations = recs
                self.isLoading = false
            }
        }
    }
}

// MARK: - Form Indicator Card

struct FormIndicatorCard: View {
    let form: FormIndicator
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Text("Recent K/D:")
                            .foregroundColor(Theme.textSecondary)
                        Text(String(format: "%.2f", form.recentKD))
                            .fontWeight(.bold)
                            .foregroundColor(form.recentKD > form.overallKD ? Theme.bf6Green : Theme.bf6Red)
                    }
                    
                    HStack {
                        Text("Overall K/D:")
                            .foregroundColor(Theme.textSecondary)
                        Text(String(format: "%.2f", form.overallKD))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    HStack {
                        Text("Recent Win Rate:")
                            .foregroundColor(Theme.textSecondary)
                        Text(String(format: "%.1f%%", form.recentWinRate))
                            .fontWeight(.bold)
                            .foregroundColor(form.recentWinRate > form.overallWinRate ? Theme.bf6Green : Theme.bf6Red)
                    }
                }
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
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            Text("Based on \(form.sessionsAnalyzed) recent sessions")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
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
