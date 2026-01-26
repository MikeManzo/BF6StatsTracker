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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Model Status
                modelStatusSection

                if let response = aiService.lastResponse {
                    // Playstyle Card
                    playstyleCard(response: response)

                    // Strengths & Weaknesses
                    strengthsWeaknessesSection(response: response)

                    // Tips Section
                    tipsSection(response: response)

                    // Session Insight
                    if let insight = response.sessionInsight {
                        sessionInsightCard(insight: insight)
                    }

                    // Timestamp
                    generatedAtFooter(response: response)
                } else if !isGenerating {
                    // Empty State
                    emptyStateView
                }
            }
            .padding()
        }
        .background(Theme.backgroundPrimary)
        .onAppear {
            // Auto-generate if we have stats but no response
            if viewModel.playerStats != nil && aiService.lastResponse == nil {
                generateAdvice()
            }
        }
        .onDisappear {
            // Unload model when leaving the view
            aiService.unloadModel()
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

            HStack {
                Text("Model Status:")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Text(aiService.isModelLoaded ? "Loaded" : "Not Loaded")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(aiService.isModelLoaded ? Theme.bf6Green : Theme.textSecondary)
            }
        }
        .padding()
        .frame(width: 320)
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

            _ = await aiService.generateCoachingAdvice(
                stats: stats,
                dailyPerformances: dailyPerformances,
                recentSnapshots: Array(recentSnapshots.prefix(50))
            )

            isGenerating = false
        }
    }
}

// MARK: - Preview

#Preview {
    AICoachView()
        .environmentObject(StatsViewModel())
        .frame(width: 800, height: 900)
}
