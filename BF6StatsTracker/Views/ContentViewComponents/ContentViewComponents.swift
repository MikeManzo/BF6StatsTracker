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
//  ContentViewComponents.swift
//  BF6StatsTracker
//
//  Reusable UI components for ContentView
//

import SwiftUI

// MARK: - Clean Stat Card

struct CleanStatCard: View {
    let value: String
    let label: String
    let color: Color
    var trend: TrendDirection? = nil

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(color)

                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption2)
                        .foregroundColor(trend.color)
                }
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
        }
        .frame(minWidth: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    @Environment(\.liquidGlassEnabled) private var liquidGlassEnabled
    let icon: String
    let tooltip: String
    var isLoading: Bool = false
    var buttonColor: Color? = nil
    var shouldPulsate: Bool = false
    let action: () -> Void

    /// True when running on macOS 26+ AND the user has the toggle on.
    private var usesLiquidGlass: Bool {
        if #available(macOS 26, *) { return liquidGlassEnabled }
        return false
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsating background circle — always show when needed to alert user of upcoming refresh
                if shouldPulsate {
                    PulsatingCircle(color: buttonColor ?? .primary)
                        .frame(width: 28, height: 28)
                }

                // Icon with color progression (green -> yellow -> red)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(buttonColor ?? .primary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
        }
        .modifier(ToolbarGlassButtonStyle(usesGlass: usesLiquidGlass))
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

/// Applies .glass buttonStyle on macOS 26+; falls back to .plain on older OS.
struct ToolbarGlassButtonStyle: ViewModifier {
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

struct ToolbarGroupGlassModifier: ViewModifier {
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *), usesGlass {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 7))
        } else {
            content
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    @Environment(\.accentColor) private var accentColor

    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(accentColor)
                .frame(width: 30)

            Text(text)
                .font(.body)
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Player Avatar View

struct PlayerAvatarView: View {
    let avatarUrl: String?
    let size: CGFloat

    @State private var avatarImage: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            if let avatarImage = avatarImage {
                Image(nsImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .task {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        guard let avatarUrl = avatarUrl,
              let url = URL(string: avatarUrl),
              !isLoading else {
            return
        }

        isLoading = true

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                await MainActor.run {
                    self.avatarImage = image
                }
            }
        } catch {
            logError("Failed to load avatar: \(error.localizedDescription)", category: .error)
        }

        isLoading = false
    }
}


