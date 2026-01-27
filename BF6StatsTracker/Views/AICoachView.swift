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
//  AICoachView.swift
//  BF6StatsTracker
//
//  AI-powered coaching view that provides personalized gameplay advice
//

import SwiftUI
import SwiftData

struct AICoachView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @StateObject private var aiService = LocalAIService.shared

    @Query(sort: \StatsSnapshot.timestamp, order: .reverse)
    private var recentSnapshots: [StatsSnapshot]

    @State private var isGenerating = false
    @State private var showModelInfo = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Model Download Section (if not downloaded)
                if !aiService.status.isDownloaded {
                    modelDownloadSection
                } else {
                    // Model Status
                    modelStatusSection

                    Group {
                        if isGenerating {
                            // Sophisticated loading animation
                            analysisLoadingSection
                        } else if let response = aiService.lastResponse {
                            // Results
                            VStack(spacing: 20) {
                                // Playstyle Card
                                playstyleCard(response: response)

                                // Strengths & Weaknesses
                                strengthsWeaknessesSection(response: response)

                                // Trend Analysis Section
                                if let trendAnalysis = response.trendAnalysis {
                                    trendAnalysisSection(trendAnalysis: trendAnalysis)
                                }

                                // Tips Section
                                tipsSection(response: response)

                                // Session Insight
                                if let insight = response.sessionInsight {
                                    sessionInsightCard(insight: insight)
                                }

                                // Timestamp
                                generatedAtFooter(response: response)
                            }
                        } else {
                            // Empty State
                            emptyStateView
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: isGenerating)
                }
            }
            .padding()
        }
        .background(Theme.backgroundPrimary)
        .onAppear {
            // Auto-generate if we have stats, model is downloaded, and no response
            if viewModel.playerStats != nil && aiService.status.isDownloaded && aiService.lastResponse == nil {
                generateAdvice()
            }
        }
        .onDisappear {
            // Unload model when leaving the view
            aiService.unloadModel()
        }
        .alert("Delete AI Model?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                aiService.deleteModel()
            }
        } message: {
            Text("This will delete the downloaded model (\(aiService.downloadedModelSize)). You can re-download it later.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(accentColor)

                    Text("AI Coach")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    experimentalBadge
                }

                Text("Personalized coaching powered by on-device AI")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // Only show generate button if model is downloaded
            if aiService.status.isDownloaded {
                // Generate Button
                Button {
                    generateAdvice()
                } label: {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.selectedText))
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "Analyzing..." : "Analyze")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.selectedText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating || viewModel.playerStats == nil)
            }

            // Info Button
            Button {
                showModelInfo.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showModelInfo) {
                modelInfoPopover
            }
        }
    }

    private var experimentalBadge: some View {
        Text("EXPERIMENTAL")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.bf6Purple)
            .cornerRadius(4)
    }

    // MARK: - Model Download Section

    private var modelDownloadSection: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.bf6Purple.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.bf6Purple)
            }

            // Title and description
            VStack(spacing: 8) {
                Text("Download AI Model")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Text("To use AI coaching, you need to download the language model. This is a one-time download that will be stored locally on your Mac.")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Model info
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    modelInfoItem(icon: "doc.zipper", label: "Model", value: aiService.modelInfo.displayName)
                    modelInfoItem(icon: "internaldrive", label: "Size", value: aiService.modelInfo.size)
                    modelInfoItem(icon: "folder", label: "Location", value: "Application Support")
                }
            }
            .padding()
            .background(Theme.overlayColor)
            .cornerRadius(12)

            // Download progress or button
            if case .downloading(let progress) = aiService.status {
                VStack(spacing: 12) {
                    ProgressView(value: progress)
                        .tint(Theme.bf6Purple)
                        .frame(width: 300)

                    HStack {
                        Text("Downloading: \(aiService.currentDownloadFile)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.bf6Purple)
                    }
                    .frame(width: 300)

                    Button {
                        aiService.cancelDownload()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(Theme.bf6Red)
                    }
                    .buttonStyle(.plain)
                }
            } else if case .error(let message) = aiService.status {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.bf6Red)

                        Text(message)
                            .font(.caption)
                            .foregroundColor(Theme.bf6Red)
                    }
                    .padding()
                    .background(Theme.bf6Red.opacity(0.1))
                    .cornerRadius(8)

                    Button {
                        Task {
                            await aiService.downloadModel()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Download")
                        }
                        .font(.headline)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.bf6Purple)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    Task {
                        await aiService.downloadModel()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download Model (\(aiService.modelInfo.size))")
                    }
                    .font(.headline)
                    .foregroundColor(Theme.selectedText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.bf6Purple)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Theme.bf6Green)

                Text("All processing happens locally. Your data never leaves your device.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding()
            .background(Theme.bf6Green.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }

    private func modelInfoItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Theme.bf6Purple)

            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
        }
        .frame(minWidth: 80)
    }

    // MARK: - Model Status

    private var modelStatusSection: some View {
        Group {
            switch aiService.status {
            case .loading(let progress):
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading AI Model...")
                            .font(.subheadline)
                            .foregroundColor(Theme.textPrimary)

                        ProgressView(value: progress)
                            .tint(accentColor)
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(12)

            case .error(let message):
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.bf6Red)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Button("Retry") {
                        generateAdvice()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Theme.bf6Red.opacity(0.1))
                .cornerRadius(12)

            case .downloaded:
                // Show a subtle indicator that model is ready
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.bf6Green)

                    Text("Model ready")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.caption)
                        .foregroundColor(Theme.bf6Red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Theme.cardBackground)
                .cornerRadius(8)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Playstyle Card

    private func playstyleCard(response: AICoachResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill.viewfinder")
                    .foregroundColor(accentColor)

                Text("Your Playstyle")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(response.playstyle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)

                Text(response.playstyleDescription)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accentColor.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Strengths & Weaknesses

    private func strengthsWeaknessesSection(response: AICoachResponse) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Strengths
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(Theme.bf6Green)

                    Text("Strengths")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(response.strengths, id: \.self) { strength in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.bf6Green)
                                .font(.caption)

                            Text(strength)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }

                    if response.strengths.isEmpty {
                        Text("Keep playing to discover your strengths")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .italic()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .cornerRadius(12)

            // Weaknesses
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(Theme.bf6Orange)

                    Text("Areas to Improve")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(response.weaknesses, id: \.self) { weakness in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Theme.bf6Orange)
                                .font(.caption)

                            Text(weakness)
                                .font(.subheadline)
                                .foregroundColor(Theme.textPrimary)
                        }
                    }

                    if response.weaknesses.isEmpty {
                        Text("No major weaknesses identified")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .italic()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Tips Section

    private func tipsSection(response: AICoachResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Theme.bf6Green)

                Text("Coaching Tips")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("\(response.tips.count) tips")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            if response.tips.isEmpty {
                Text("Play more matches to receive personalized tips")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(response.tips) { tip in
                        tipCard(tip: tip)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private func tipCard(tip: AICoachTip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: tip.category.icon)
                    .foregroundColor(tip.category.color)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tip.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)

                    Text(tip.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                // Priority indicator
                Circle()
                    .fill(tip.priority.color)
                    .frame(width: 8, height: 8)
            }

            Text(tip.description)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(10)
    }

    // MARK: - Trend Analysis Section

    private func trendAnalysisSection(trendAnalysis: TrendAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(accentColor)

                Text("Trend Analysis")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)

                Spacer()
            }

            // Status Cards Row
            HStack(spacing: 12) {
                // Trajectory Card
                trendStatusCard(
                    title: "Trajectory",
                    value: trendAnalysis.trajectory.rawValue,
                    icon: trendAnalysis.trajectory.icon,
                    color: trendAnalysis.trajectory.color
                )

                // Consistency Card
                trendStatusCard(
                    title: "Consistency",
                    value: trendAnalysis.consistency.rawValue,
                    icon: trendAnalysis.consistency.icon,
                    color: trendAnalysis.consistency.color
                )

                // Momentum Card
                trendStatusCard(
                    title: "Momentum",
                    value: trendAnalysis.momentumStatus.rawValue,
                    icon: trendAnalysis.momentumStatus.icon,
                    color: trendAnalysis.momentumStatus.color
                )
            }

            // Peak Performance Section
            if let peak = trendAnalysis.peakPerformance {
                peakPerformanceCard(peak: peak)
            }

            // Trend Insights
            if !trendAnalysis.insights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textSecondary)

                    ForEach(trendAnalysis.insights) { insight in
                        trendInsightRow(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    private func trendStatusCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func peakPerformanceCard(peak: PeakPerformanceInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)

                Text("Peak Performance")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
            }

            HStack(spacing: 16) {
                if let timeOfDay = peak.bestTimeOfDay {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text(timeOfDay)
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary)
                    }
                }

                if let dayOfWeek = peak.bestDayOfWeek {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text(dayOfWeek)
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }

            Text(peak.recommendation)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.overlayColor)
        .cornerRadius(8)
    }

    private func trendInsightRow(insight: TrendInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.category.icon)
                .font(.body)
                .foregroundColor(insight.category.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)

                    if let dataPoint = insight.dataPoint {
                        Text(dataPoint)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(insight.category.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(insight.category.color.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.overlayColor)
        .cornerRadius(8)
    }

    // MARK: - Session Insight

    private func sessionInsightCard(insight: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Theme.bf6Blue)

                Text("Performance Trend")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }

            Text(insight)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Footer

    private func generatedAtFooter(response: AICoachResponse) -> some View {
        HStack {
            Image(systemName: "clock")
                .font(.caption2)

            Text("Generated \(response.generatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption)
        }
        .foregroundColor(Theme.textSecondary)
    }

    // MARK: - Analysis Loading Animation

    private var analysisLoadingSection: some View {
        VStack(spacing: 16) {
            AIAnalysisLoadingView()

            Text("This may take a moment while the AI model processes your stats")
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.5))

            Text("Ready to Analyze")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text("Click \"Analyze\" to get personalized coaching advice based on your gameplay statistics.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if viewModel.playerStats == nil {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.bf6Orange)

                    Text("No player stats loaded. Please enter a player name first.")
                        .font(.caption)
                        .foregroundColor(Theme.bf6Orange)
                }
                .padding()
                .background(Theme.bf6Orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Model Info Popover

    private var modelInfoPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About AI Coach")
                .font(.headline)
                .foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "cpu", title: "On-Device Processing", description: "All analysis runs locally on your Mac using Apple Silicon")

                infoRow(icon: "lock.shield", title: "Privacy First", description: "Your stats never leave your device")

                infoRow(icon: "memorychip", title: "Memory Usage", description: "~2GB RAM when active, freed when you leave this tab")

                infoRow(icon: "bolt", title: "Apple Silicon Optimized", description: "Uses Neural Engine and GPU for fast inference")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Model:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(aiService.modelInfo.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                }

                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text(aiService.status.displayText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(aiService.isModelLoaded ? Theme.bf6Green : Theme.textSecondary)
                }

                if aiService.status.isDownloaded {
                    HStack {
                        Text("Size on Disk:")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Text(aiService.downloadedModelSize)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .padding()
        .frame(width: 340)
    }

    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - Actions

    private func generateAdvice() {
        guard let stats = viewModel.playerStats else { return }

        isGenerating = true

        Task {
            let dailyPerformances = HistoryManager.shared.getRecentDailyPerformances(
                days: 30,
                playerName: stats.userName
            )

            // Gather trend data for analysis
            let trendData = aiService.gatherTrendData(from: HistoryManager.shared, days: 30)

            _ = await aiService.generateCoachingAdvice(
                stats: stats,
                dailyPerformances: dailyPerformances,
                recentSnapshots: Array(recentSnapshots.prefix(50)),
                trendData: trendData
            )

            isGenerating = false
        }
    }
}

// MARK: - AI Analysis Loading Animation

/// A sophisticated cascading data analysis animation for the AI Coach
/// Shows stat items flowing upward as they're being "analyzed"
private struct AIAnalysisLoadingView: View {
    @Environment(\.accentColor) private var accentColor

    // Animation state
    @State private var particles: [AnalysisParticle] = []
    @State private var centralPulse: CGFloat = 1.0
    @State private var centralRotation: Double = 0
    @State private var processingPhase: Int = 0
    @State private var scanLineOffset: CGFloat = 0

    // Timer for spawning particles
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    let phaseTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    // Stat items to cycle through
    private let statItems: [(icon: String, label: String)] = [
        ("target", "Accuracy"),
        ("person.fill.viewfinder", "K/D Ratio"),
        ("flame.fill", "Kills"),
        ("clock.fill", "Time Played"),
        ("trophy.fill", "Score"),
        ("star.fill", "SPM"),
        ("bolt.fill", "Headshots"),
        ("chart.line.uptrend.xyaxis", "Win Rate"),
        ("scope", "Kills/Min"),
        ("heart.fill", "Revives")
    ]

    private let processingPhases = [
        "Analyzing combat patterns...",
        "Evaluating accuracy metrics...",
        "Processing K/D trends...",
        "Identifying strengths...",
        "Generating insights..."
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Main animation container
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(0.15),
                                accentColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(centralPulse)

                // Scan line effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                accentColor.opacity(0.3),
                                accentColor.opacity(0.5),
                                accentColor.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 200, height: 2)
                    .offset(y: scanLineOffset - 100)
                    .mask(
                        RoundedRectangle(cornerRadius: 100)
                            .frame(width: 200, height: 200)
                    )

                // Floating particles
                ForEach(particles) { particle in
                    AnalysisParticleView(particle: particle, accentColor: accentColor)
                }

                // Central processing indicator
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .trim(from: 0.0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [accentColor, Theme.bf6Purple, accentColor.opacity(0.3)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(centralRotation))

                    // Inner rotating ring (opposite direction)
                    Circle()
                        .trim(from: 0.2, to: 0.5)
                        .stroke(
                            AngularGradient(
                                colors: [Theme.bf6Purple.opacity(0.5), accentColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-centralRotation * 1.5))

                    // Center icon
                    ZStack {
                        Circle()
                            .fill(Theme.cardBackground)
                            .frame(width: 50, height: 50)

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentColor, Theme.bf6Purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(centralPulse * 0.9 + 0.1)
                    }
                }

                // Data stream lines
                ForEach(0..<6, id: \.self) { index in
                    DataStreamLine(
                        index: index,
                        accentColor: accentColor,
                        rotation: centralRotation
                    )
                }
            }
            .frame(width: 300, height: 250)

            // Processing phase text
            VStack(spacing: 8) {
                Text(processingPhases[processingPhase])
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                    .animation(.easeInOut(duration: 0.3), value: processingPhase)

                // Animated dots
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                            .opacity(Double((processingPhase + index) % 3 == 0 ? 1.0 : 0.3))
                            .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.15), value: processingPhase)
                    }
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .onReceive(timer) { _ in
            spawnParticle()
        }
        .onReceive(phaseTimer) { _ in
            withAnimation {
                processingPhase = (processingPhase + 1) % processingPhases.count
            }
        }
    }

    private func startAnimations() {
        // Central pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            centralPulse = 1.1
        }

        // Central rotation animation
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            centralRotation = 360
        }

        // Scan line animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            scanLineOffset = 200
        }

        // Spawn initial particles
        for _ in 0..<5 {
            spawnParticle()
        }
    }

    private func spawnParticle() {
        let randomStat = statItems.randomElement()!
        let startX = CGFloat.random(in: -100...100)
        let particle = AnalysisParticle(
            id: UUID(),
            icon: randomStat.icon,
            label: randomStat.label,
            startPosition: CGPoint(x: startX, y: 120),
            endPosition: CGPoint(x: startX + CGFloat.random(in: -30...30), y: -120),
            duration: Double.random(in: 2.0...3.5)
        )

        withAnimation(.easeOut(duration: particle.duration)) {
            particles.append(particle)
        }

        // Remove particle after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + particle.duration) {
            particles.removeAll { $0.id == particle.id }
        }
    }
}

// MARK: - Analysis Particle Model

private struct AnalysisParticle: Identifiable {
    let id: UUID
    let icon: String
    let label: String
    let startPosition: CGPoint
    let endPosition: CGPoint
    let duration: Double
}

// MARK: - Analysis Particle View

private struct AnalysisParticleView: View {
    let particle: AnalysisParticle
    let accentColor: Color

    @State private var progress: CGFloat = 0
    @State private var opacity: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: particle.icon)
                .font(.caption)
                .foregroundColor(accentColor)

            Text(particle.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.cardBackground)
                .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .overlay(
            Capsule()
                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
        )
        .position(
            x: 150 + particle.startPosition.x + (particle.endPosition.x - particle.startPosition.x) * progress,
            y: 125 + particle.startPosition.y + (particle.endPosition.y - particle.startPosition.y) * progress
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: particle.duration)) {
                progress = 1
            }
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(particle.duration - 0.5)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Data Stream Line

private struct DataStreamLine: View {
    let index: Int
    let accentColor: Color
    let rotation: Double

    @State private var dashPhase: CGFloat = 0

    private var angle: Double {
        Double(index) * 60
    }

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 150, y: 125))
            let endX = 150 + cos((angle + rotation * 0.2) * .pi / 180) * 100
            let endY = 125 + sin((angle + rotation * 0.2) * .pi / 180) * 100
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(
            accentColor.opacity(0.2),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 8], dashPhase: dashPhase)
        )
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                dashPhase = -12
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AICoachView()
        .environmentObject(StatsViewModel())
        .frame(width: 800, height: 900)
}
