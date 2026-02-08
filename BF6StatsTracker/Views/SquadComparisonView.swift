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
//  SquadComparisonView.swift
//  BF6StatsTracker
//
//  Squad comparison view for comparing stats with up to 3 squadmates
//

import SwiftUI

struct SquadComparisonView: View {
    @Environment(\.accentColor) private var accentColor
    @EnvironmentObject var viewModel: StatsViewModel
    @StateObject private var squadService = SquadService.shared
    @State private var showAddMemberSheet = false
    @State private var showInfoSheet = false
    @State private var expandedCategories: Set<MetricCategory> = Set(MetricCategory.allCases)
    
    private var allMembers: [SquadMember] {
        var members: [SquadMember] = []
        
        // Add current user as first member
        if let currentUserStats = viewModel.playerStats {
            let currentUser = SquadMember(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                eaId: viewModel.settings.eaId ?? viewModel.settings.playerName,
                platform: viewModel.settings.platform,
                displayName: "You"
            )
            var userMember = currentUser
            userMember.stats = currentUserStats
            userMember.lastFetched = Date()
            members.append(userMember)
        }
        
        // Add squad members
        members.append(contentsOf: squadService.squadMembers)
        
        return members
    }
    
    private var comparison: SquadComparison {
        SquadComparison(members: allMembers)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            header
            
            // Member Cards
            memberCardsSection
            
            // Comparison Sections
            if !allMembers.isEmpty && allMembers.first?.isLoaded == true {
                // Squad order header
                squadOrderHeader
                
                ForEach(MetricCategory.allCases) { category in
                    metricCategorySection(category: category)
                }
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberSheet(squadService: squadService)
        }
        .sheet(isPresented: $showInfoSheet) {
            InfoSheet()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.title)
                        .foregroundColor(accentColor)
                    
                    Text("Squad Comparison")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                    
                    // Info Button
                    Button(action: {
                        showInfoSheet = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textPrimary)
                            .padding(8)
 //                           .background(Theme.backgroundSecondary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                if let lastRefresh = squadService.lastRefreshDate {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            // Refresh Button
            Button(action: {
                Task {
                    // Refresh current user stats
                    await viewModel.refreshStats()
                    // Refresh squad members
                    await squadService.refreshAllMembers()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(squadService.isRefreshing)
            .opacity(squadService.isRefreshing ? 0.5 : 1.0)
        }
        .padding(12)
        .background(Theme.overlayColor)
        .cornerRadius(10)
    }
    
    // MARK: - Squad Order Header
    
    private var squadOrderHeader: some View {
        HStack(spacing: 12) {
            // Label section
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.system(size: 12))
                    .foregroundColor(accentColor)
                
                Text("Squad Order")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: 180, alignment: .leading)
            
            // Member names
            HStack(spacing: 10) {
                ForEach(allMembers) { member in
                    VStack(spacing: 4) {
                        // Member name
                        Text(member.effectiveName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        
                        // Platform icon
                        HStack(spacing: 3) {
                            Image(systemName: member.platform.icon)
                                .font(.system(size: 8))
                            Text(member.platform.displayName)
                                .font(.system(size: 8))
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    .frame(width: 85)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(member.id.uuidString == "00000000-0000-0000-0000-000000000000" 
                                ? accentColor.opacity(0.15)
                                : Theme.backgroundSecondary.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                member.id.uuidString == "00000000-0000-0000-0000-000000000000"
                                    ? accentColor.opacity(0.3)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.overlayColor)
        .cornerRadius(10)
    }
    
    // MARK: - Member Cards Section
    
    private var memberCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Current User Card
                if let firstMember = allMembers.first {
                    SquadMemberCard(
                        member: firstMember,
                        isCurrentUser: true,
                        accentColor: accentColor,
                        onRetry: nil,
                        onRemove: nil
                    )
                }
                
                // Squad Member Cards
                ForEach(squadService.squadMembers) { member in
                    SquadMemberCard(
                        member: member,
                        isCurrentUser: false,
                        accentColor: accentColor,
                        onRetry: {
                            Task {
                                await squadService.retryMember(id: member.id)
                            }
                        },
                        onRemove: {
                            squadService.removeMember(id: member.id)
                        }
                    )
                    .id("\(member.id)-\(member.lastFetched?.timeIntervalSince1970 ?? 0)")
                }
                
                // Add Member Card
                if squadService.squadMembers.count < 3 {
                    AddMemberCard(accentColor: accentColor) {
                        showAddMemberSheet = true
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Metric Category Section
    
    private func metricCategorySection(category: MetricCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Header
            Button(action: {
                withAnimation {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            }) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 13))
                        .foregroundColor(accentColor)
                    
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    // Category winner indicator
                    if let winner = categoryWinner(for: category) {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            
                            Text(winner)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15))
                        )
                    }
                    
                    Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 10))
                }
                .padding(10)
                .background(Theme.backgroundSecondary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // Metrics
            if expandedCategories.contains(category) {
                VStack(spacing: 4) {
                    ForEach(ComparisonMetric.allCases.filter { $0.category == category }) { metric in
                        MetricComparisonRow(
                            metric: metric,
                            comparison: comparison,
                            accentColor: accentColor
                        )
                        .id("\(metric.id)-\(allMembers.map { $0.lastFetched?.timeIntervalSince1970 ?? 0 }.reduce(0, +))")
                    }
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    
    private func categoryWinner(for category: MetricCategory) -> String? {
        let metrics = ComparisonMetric.allCases.filter { $0.category == category }
        guard !metrics.isEmpty else { return nil }
        
        var winCounts: [UUID: Int] = [:]
        
        for metric in metrics {
            let rankings = comparison.rankings(for: metric)
            if let winnerId = rankings.first(where: { $0.value == 1 })?.key {
                winCounts[winnerId, default: 0] += 1
            }
        }
        
        guard let overallWinnerId = winCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        if let winner = comparison.members.first(where: { $0.id == overallWinnerId }) {
            return winner.displayName ?? winner.eaId
        }
        
        return nil
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            // Animated icon with pulsing effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentColor.opacity(0.2), accentColor.opacity(0.05)],
                            center: .center,
                            startRadius: 15,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text("Build Your Squad")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                Text("Add up to 3 squadmates to compare your stats and see who ranks first")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            
            Button(action: { showAddMemberSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Squad Member")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .shadow(color: accentColor.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.overlayColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [accentColor.opacity(0.3), accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Squad Member Card

struct SquadMemberCard: View {
    let member: SquadMember
    let isCurrentUser: Bool
    let accentColor: Color
    let onRetry: (() -> Void)?
    let onRemove: (() -> Void)?
    
    private var cardGradient: LinearGradient {
        if isCurrentUser {
            return LinearGradient(
                colors: [accentColor.opacity(0.12), accentColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Theme.backgroundSecondary, Theme.backgroundSecondary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(member.effectiveName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            
                            if isCurrentUser {
                                Text("YOU")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(accentColor.opacity(0.7))
                                    .cornerRadius(3)
                            }
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: member.platform.icon)
                                .font(.system(size: 9))
                            Text(member.platform.displayName)
                                .font(.system(size: 9))
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    if !isCurrentUser, let onRemove = onRemove {
                        Button(action: onRemove) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Stats
                if member.isLoaded, let stats = member.stats {
                    VStack(spacing: 8) {
                        // Top row - Primary combat stats
                        HStack(spacing: 8) {
                            statBoxCompact(
                                label: "K/D",
                                value: String(format: "%.2f", stats.kdRatio),
                                icon: "chart.line.uptrend.xyaxis",
                                color: .orange
                            )
                            
                            statBoxCompact(
                                label: "Kills",
                                value: "\(stats.kills)",
                                icon: "scope",
                                color: .red
                            )
                            
                            statBoxCompact(
                                label: "Deaths",
                                value: "\(stats.deaths)",
                                icon: "xmark",
                                color: .gray
                            )
                        }
                        
                        // Bottom row - Secondary stats
                        HStack(spacing: 8) {
                            statBoxCompact(
                                label: "Accuracy",
                                value: String(format: "%.1f%%", stats.accuracy),
                                icon: "target",
                                color: .blue
                            )
                            
                            statBoxCompact(
                                label: "Win Rate",
                                value: String(format: "%.1f%%", stats.wlRatio),
                                icon: "flag.fill",
                                color: .green
                            )
                            
                            statBoxCompact(
                                label: "Rank",
                                value: "\(stats.rank)",
                                icon: "star.fill",
                                color: .purple
                            )
                        }
                    }
                } else if member.hasError {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        
                        Text("Failed to load")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        
                        if let onRetry = onRetry {
                            Button("Retry") {
                                onRetry()
                            }
                            .font(.system(size: 10))
                            .foregroundColor(accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(cardGradient)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isCurrentUser
                        ? LinearGradient(colors: [accentColor.opacity(0.4), accentColor.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: isCurrentUser ? 1.5 : 0
                )
        )
        .cornerRadius(16)
        .shadow(color: isCurrentUser ? accentColor.opacity(0.15) : Color.black.opacity(0.1), radius: isCurrentUser ? 8 : 6, y: 4)
    }
    
    private func statBoxCompact(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Add Member Card

struct AddMemberCard: View {
    let accentColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(accentColor)
                
                Text("Add Member")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(width: 200, height: 180)
            .background(Theme.backgroundSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(accentColor.opacity(0.5))
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Member Sheet

struct AddMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentColor) private var accentColor
    @ObservedObject var squadService: SquadService
    
    @State private var eaId: String = ""
    @State private var selectedPlatform: Platform = .pc
    @State private var displayName: String = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Squad Member")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Form
            VStack(alignment: .leading, spacing: 16) {
                // EA ID
                VStack(alignment: .leading, spacing: 8) {
                    Text("EA ID")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    TextField("Enter EA ID", text: $eaId)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Theme.backgroundSecondary)
                        .cornerRadius(8)
                }
                
                // Platform
                VStack(alignment: .leading, spacing: 8) {
                    Text("Platform")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach([Platform.pc, Platform.playstation, Platform.xbox], id: \.self) { platform in
                            Text(platform.displayName).tag(platform)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Display Name (Optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name (Optional)")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    TextField("Nickname", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Theme.backgroundSecondary)
                        .cornerRadius(8)
                }
            }
            
            // Error Message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            // Add Button
            Button(action: addMember) {
                if isAdding {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Add to Squad")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(eaId.isEmpty ? Color.gray : accentColor)
            .cornerRadius(10)
            .disabled(eaId.isEmpty || isAdding)
        }
        .padding(24)
        .frame(width: 400, height: 500)
        .background(Theme.backgroundPrimary)
    }
    
    private func addMember() {
        errorMessage = nil
        isAdding = true
        
        Task {
            do {
                let name = displayName.isEmpty ? nil : displayName
                try await squadService.addMember(eaId: eaId, platform: selectedPlatform, displayName: name)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAdding = false
                }
            }
        }
    }
}

// MARK: - Metric Comparison Row

struct MetricComparisonRow: View {
    let metric: ComparisonMetric
    let comparison: SquadComparison
    let accentColor: Color
    
    private var rankings: [UUID: Int] {
        comparison.rankings(for: metric)
    }
    
    private var maxValue: Double {
        comparison.members.compactMap { member in
            comparison.value(for: member, metric: metric)
        }.max() ?? 1.0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Metric Label
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: metric.icon)
                        .font(.system(size: 12))
                        .foregroundColor(accentColor)
                }
                
                Text(metric.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
            }
            .frame(width: 180, alignment: .leading)
            
            // Rankings for each member with full stat display
            HStack(spacing: 10) {
                ForEach(comparison.members) { member in
                    if let value = comparison.value(for: member, metric: metric),
                       let rank = rankings[member.id] {
                        VStack(spacing: 4) {
                            // Rank badge
                            ZStack {
                                // Outer glow
                                if rank <= 3 {
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [rankBadgeColor(for: rank).opacity(0.4), rankBadgeColor(for: rank).opacity(0.0)],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 16
                                            )
                                        )
                                        .frame(width: 32, height: 32)
                                        .blur(radius: 2)
                                }
                                
                                Circle()
                                    .fill(rankBadgeGradient(for: rank))
                                    .frame(width: 26, height: 26)
                                    .shadow(color: .black.opacity(0.3), radius: 3)
                                
                                // Dark inner circle for better contrast
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 24, height: 24)
                                
                                if rank == 1 {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.7), radius: 1.5)
                                } else if rank == 2 {
                                    Image(systemName: "medal.fill")
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.7), radius: 1.5)
                                } else if rank == 3 {
                                    Image(systemName: "medal.fill")
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.7), radius: 1.5)
                                } else {
                                    Text("\(rank)")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.7), radius: 1.5)
                                }
                            }
                            
                            // Value with background bar
                            ZStack {
                                // Background bar
                                GeometryReader { geo in
                                    let barWidth = maxValue > 0 ? (value / maxValue) * geo.size.width : 0
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: barGradientColors(for: rank),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: barWidth)
                                }
                                
                                // Value text
                                Text(metric.formatValue(value))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                            }
                            .frame(height: 24)
                        }
                        .frame(width: 85)
                    } else {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 20, height: 20)
                            
                            Text("—")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .frame(height: 24)
                        }
                        .frame(width: 85)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Theme.backgroundSecondary.opacity(0.5))
        .cornerRadius(8)
    }
    
    private func barGradientColors(for rank: Int) -> [Color] {
        switch rank {
        case 1:
            return [Color.green.opacity(0.6), Color.green.opacity(0.3)]
        case 2:
            return [Color.yellow.opacity(0.6), Color.yellow.opacity(0.3)]
        case 3:
            return [Color.orange.opacity(0.6), Color.orange.opacity(0.3)]
        default:
            return [Color.red.opacity(0.5), Color.red.opacity(0.2)]
        }
    }
    
    private func rankBadgeGradient(for rank: Int) -> LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.95, blue: 0.3),
                    Color(red: 1.0, green: 0.84, blue: 0.0),
                    Color(red: 0.9, green: 0.7, blue: 0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.95),
                    Color(red: 0.8, green: 0.8, blue: 0.8),
                    Color(red: 0.65, green: 0.65, blue: 0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.65, blue: 0.4),
                    Color(red: 0.82, green: 0.5, blue: 0.25),
                    Color(red: 0.7, green: 0.4, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.secondary.opacity(0.7), Color.secondary.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func rankBadgeColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.85, green: 0.85, blue: 0.85)
        case 3: return Color(red: 0.9, green: 0.55, blue: 0.25)
        default: return Color.clear
        }
    }
}

// MARK: - Ranking Badge

struct RankingBadge: View {
    let rank: Int
    let value: String
    let accentColor: Color
    
    private var badgeGradient: LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.23),
                    Color(red: 1.0, green: 0.84, blue: 0.0),
                    Color(red: 0.85, green: 0.65, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.85, blue: 0.85),
                    Color(red: 0.7, green: 0.7, blue: 0.7),
                    Color(red: 0.55, green: 0.55, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.58, blue: 0.35),
                    Color(red: 0.72, green: 0.45, blue: 0.2),
                    Color(red: 0.6, green: 0.35, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.secondary.opacity(0.6), Color.secondary.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var glowColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.clear
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Rank Circle with Glow
            ZStack {
                // Outer glow effect (reduced)
                if rank <= 3 {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [glowColor.opacity(0.3), glowColor.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 14
                            )
                        )
                        .frame(width: 28, height: 28)
                        .blur(radius: 2)
                }
                
                // Main badge circle
                Circle()
                    .fill(badgeGradient)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: glowColor.opacity(rank <= 3 ? 0.4 : 0.15), radius: rank == 1 ? 4 : 2)
                
                // Icon or number
                if rank == 1 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 0.5)
                } else if rank == 2 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 0.5)
                } else if rank == 3 {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 0.5)
                } else {
                    Text("\(rank)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 0.5)
                }
            }
            
            // Value
            Text(value)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(rank <= 3 ? glowColor : Theme.textPrimary)
                .lineLimit(1)
        }
    }
}

// MARK: - Info Sheet

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accentColor) private var accentColor
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Squad Comparison Guide")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Theme.backgroundSecondary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Ranking Badges Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ranking Badges")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            infoRow(
                                icon: "trophy.fill",
                                iconColor: Color(red: 1.0, green: 0.84, blue: 0.0),
                                title: "1st Place - Gold",
                                description: "Highest performance in this metric"
                            )
                            
                            infoRow(
                                icon: "medal.fill",
                                iconColor: Color(red: 0.75, green: 0.75, blue: 0.75),
                                title: "2nd Place - Silver",
                                description: "Second highest performance"
                            )
                            
                            infoRow(
                                icon: "medal.fill",
                                iconColor: Color(red: 0.8, green: 0.5, blue: 0.2),
                                title: "3rd Place - Bronze",
                                description: "Third highest performance"
                            )
                            
                            infoRow(
                                icon: "4.circle.fill",
                                iconColor: Color.secondary,
                                title: "4th Place",
                                description: "Lowest performance in the squad"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Background Bars Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Bars")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("Each stat displays a colored background bar showing relative performance:")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            barExample(color: .green, title: "Green Bar", description: "1st place performance")
                            barExample(color: .yellow, title: "Yellow Bar", description: "2nd place performance")
                            barExample(color: .orange, title: "Orange Bar", description: "3rd place performance")
                            barExample(color: .red, title: "Red Bar", description: "4th place performance")
                        }
                        
                        Text("The bar width shows the value relative to the best performer (100% width = highest value).")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 4)
                    }
                    
                    Divider()
                    
                    // Category Winners Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Winners")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            
                            Text("Example Name")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15))
                        )
                        
                        Text("The crown badge shows who won the most metrics in each category (Combat, Team Support, etc.).")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Divider()
                    
                    // Tips Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            tipRow("Click category headers to expand or collapse sections")
                            tipRow("Use the Refresh button to update all squad stats")
                            tipRow("Add up to 3 squadmates to compare")
                            tipRow("Your card is highlighted with a border and \"YOU\" badge")
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
        .background(Theme.backgroundPrimary)
    }
    
    private func infoRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func barExample(color: Color, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.6), color.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
        }
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(accentColor)
            
            Text(text)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SquadComparisonView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 900)
}
