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
//  StateViews.swift
//  BF6StatsTracker
//
//  Loading and welcome state views
//

import SwiftUI

// MARK: - Loading View

struct LoadingStateView: View {
    @Environment(\.accentColor) private var accentColor
    @State private var rotationAngle: Double = 0
    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                // Background pulse circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale(for: index))
                        .opacity(pulseOpacity(for: index))
                }

                // Center icon
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, Theme.bf6Red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(rotationAngle))
            }
            .frame(height: 200)

            VStack(spacing: 12) {
                Text("Loading Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Text("Preparing your battlefield data...")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private func pulseScale(for index: Int) -> CGFloat {
        let baseScale: CGFloat = 1.0 + (CGFloat(index) * 0.3)
        return isPulsing ? baseScale + 0.2 : baseScale
    }

    private func pulseOpacity(for index: Int) -> Double {
        let _ = Double(index) * 0.2  // Delay calculation for future animation use
        return isPulsing ? 0.0 : 0.6
    }
}

// MARK: - Welcome View

struct WelcomeStateView: View {
    @Environment(\.accentColor) private var accentColor
    @StateObject private var accountStore = EAAccountStore.shared
    @Binding var showingSearch: Bool
    @Binding var showingEALogin: Bool
    @Binding var showingAccountSelection: Bool

    var body: some View {
        VStack(spacing: 30) {
            // Logo/Icon
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 10) {
                Text("BF6 Stats Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                Text("Track your Battlefield 6 statistics in real-time")
                    .font(.title3)
                    .foregroundColor(Theme.textSecondary)
            }

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "person.badge.key.fill", text: "EA Account integration")
                FeatureRow(icon: "person.3.fill", text: "All 4 classes with detailed stats")
                FeatureRow(icon: "scope", text: "45+ weapons tracking")
                FeatureRow(icon: "car.fill", text: "8 vehicle categories")
                FeatureRow(icon: "wrench.and.screwdriver.fill", text: "Gadget performance")
                FeatureRow(icon: "clock.arrow.circlepath", text: "Auto-refresh every 5 minutes")
            }
            .padding(30)
            .background(Theme.overlayColor)
            .cornerRadius(16)

            // Action buttons
            VStack(spacing: 16) {
                // Show account selection if accounts exist, otherwise EA Login
                if !accountStore.accounts.isEmpty {
                    // Account Selection Button (Primary)
                    Button {
                        showingAccountSelection = true
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Choose Saved Account")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .frame(minWidth: 280)
                        .background(
                            LinearGradient(
                                colors: [accentColor, Theme.bf6Red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    // EA Login Button (Secondary)
                    Button {
                        showingEALogin = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in with different account")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .frame(minWidth: 280)
                        .background(
                            LinearGradient(
                                colors: [Theme.bf6Blue, Theme.bf6Purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    // EA Login Button (Primary)
                    Button {
                        showingEALogin = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.key.fill")
                            Text("Sign in with EA")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .frame(minWidth: 280)
                        .background(
                            LinearGradient(
                                colors: [accentColor, Theme.bf6Red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    Text("or")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    // Manual Search Button (Secondary)
                    Button {
                        showingSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search Player Manually")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.selectedText)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .frame(minWidth: 280)
                        .background(
                            LinearGradient(
                                colors: [Theme.bf6Blue, Theme.bf6Purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Info text
            VStack(spacing: 4) {
                Text("Powered by GameTools.Network API")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text("EA Identity via EAIdentityKit")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(40)
    }
}
