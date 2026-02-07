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
    @State private var expandedCategories: Set<MetricCategory> = Set(MetricCategory.allCases)
    
    private var allMembers: [SquadMember] {
        var members: [SquadMember] = []
        
        // Add current user as first member
        if let currentUserStats = viewModel.stats {
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
        ScrollView {
            VStack(spacing: 20) {
                // Header
                header
                
                // Member Cards
                memberCardsSection
                
                // Comparison Sections
                if !allMembers.isEmpty && allMembers.first?.isLoaded == true {
                    ForEach(MetricCategory.allCases) { category in
                        metricCategorySection(category: category)
                    }
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .background(Theme.backgroundPrimary.ignoresSafeArea())
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberSheet(squadService: squadService)
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
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
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
                        .foregroundColor(accentColor)
                    
                    Text(category.rawValue)
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                        .foregroundColor(Theme.textSecondary)
                        .font(.caption)
                }
                .padding()
                .background(Theme.backgroundSecondary)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            // Metrics
            if expandedCategories.contains(category) {
                VStack(spacing: 8) {
                    ForEach(ComparisonMetric.allCases.filter { $0.category == category }) { metric in
                        MetricComparisonRow(
                            metric: metric,
                            comparison: comparison,
                            accentColor: accentColor
                        )
                    }
                }
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.textSecondary)
            
            Text("Build Your Squad")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Text("Add up to 3 squadmates to compare your stats")
                .font(.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showAddMemberSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Squad Member")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(accentColor)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
}

// MARK: - Squad Member Card

struct SquadMemberCard: View {
    let member: SquadMember
    let isCurrentUser: Bool
    let accentColor: Color
    let onRetry: (() -> Void)?
    let onRemove: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(member.effectiveName)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundColor(accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentColor.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: member.platform.iconName)
                            .font(.caption2)
                        Text(member.platform.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if !isCurrentUser, let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // Stats
            if member.isLoaded, let stats = member.stats {
                VStack(spacing: 8) {
                    statRow(icon: "number", label: "Rank", value: "\(stats.rank)")
                    statRow(icon: "chart.line.uptrend.xyaxis", label: "K/D", value: String(format: "%.2f", stats.kdRatio))
                    statRow(icon: "scope", label: "Kills", value: "\(stats.kills)")
                    statRow(icon: "target", label: "Accuracy", value: String(format: "%.1f%%", stats.accuracy))
                }
            } else if member.hasError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Failed to load")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    if let onRetry = onRetry {
                        Button("Retry") {
                            onRetry()
                        }
                        .font(.caption)
                        .foregroundColor(accentColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .padding()
        .frame(width: 200)
        .background(isCurrentUser ? accentColor.opacity(0.1) : Theme.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentUser ? accentColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
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
                        ForEach(Platform.allCases, id: \.self) { platform in
                            HStack {
                                Image(systemName: platform.iconName)
                                Text(platform.rawValue)
                            }
                            .tag(platform)
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Metric Label
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.caption)
                    .foregroundColor(accentColor)
                    .frame(width: 20)
                
                Text(metric.rawValue)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
            }
            .frame(width: 180, alignment: .leading)
            
            // Rankings for each member
            HStack(spacing: 8) {
                ForEach(comparison.members) { member in
                    if let value = comparison.value(for: member, metric: metric),
                       let rank = rankings[member.id] {
                        RankingBadge(
                            rank: rank,
                            value: metric.formatValue(value),
                            accentColor: accentColor
                        )
                        .frame(width: 80)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 80)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Theme.backgroundSecondary.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Ranking Badge

struct RankingBadge: View {
    let rank: Int
    let value: String
    let accentColor: Color
    
    private var badgeColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.secondary.opacity(0.5)
        }
    }
    
    private var badgeGradient: LinearGradient {
        switch rank {
        case 1: return LinearGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.0)], startPoint: .top, endPoint: .bottom)
        case 2: return LinearGradient(colors: [Color(red: 0.75, green: 0.75, blue: 0.75), Color(red: 0.66, green: 0.66, blue: 0.66)], startPoint: .top, endPoint: .bottom)
        case 3: return LinearGradient(colors: [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.72, green: 0.45, blue: 0.2)], startPoint: .top, endPoint: .bottom)
        default: return LinearGradient(colors: [Color.secondary.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Rank Circle
            ZStack {
                Circle()
                    .fill(badgeGradient)
                    .frame(width: 32, height: 32)
                
                if rank == 1 {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Text("\(rank)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            // Value
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
        }
    }
}

// MARK: - Preview

#Preview {
    SquadComparisonView()
        .environmentObject(StatsViewModel())
        .frame(width: 1200, height: 900)
}
