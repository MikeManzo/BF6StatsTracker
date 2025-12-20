//
//  ClassTileView.swift
//  BF6StatsTracker
//
//  Stylish, draggable class tiles for Battlefield 6 classes
//

import SwiftUI

struct ClassTileView: View {
    let classStats: ClassStats
    let position: TilePosition
    let onPositionChange: (TilePosition) -> Void
    
    @State private var isHovered = false
    @State private var isExpanded = false
    
    private var bf6Class: BF6Class {
        BF6Class(rawValue: classStats.className) ?? .assault
    }
    
    var body: some View {
        mainTileContent
            .frame(maxWidth: .infinity)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(tileOverlay)
            .shadow(color: bf6Class.color.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 20 : 10)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
            .animation(.spring(response: 0.3), value: isExpanded)
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.4)) {
                    isExpanded.toggle()
                }
            }
    }
    
    // MARK: - Main Tile Content
    
    private var mainTileContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                ClassIconView(className: bf6Class, size: 50, imageURL: classStats.image)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(classStats.className)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)

                    Text(bf6Class.description)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            Divider()
                .background(Theme.borderColor)
            
            // Stats Grid
            if isExpanded {
                expandedStats
            } else {
                compactStats
            }

            // Footer
            HStack {
                Label("\(classStats.timePlayed / 3600)h \((classStats.timePlayed % 3600) / 60)m", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                if isExpanded {
                    Button {
                        withAnimation(.spring()) {
                            isExpanded = false
                        }
                    } label: {
                        Label("Collapse", systemImage: "chevron.up")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Compact Stats

    private var compactStats: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            CompactStatItem(
                label: "Kills",
                value: "\(classStats.kills)",
                icon: "target",
                color: Theme.bf6Red
            )

            CompactStatItem(
                label: "Deaths",
                value: "\(classStats.deaths)",
                icon: "xmark.circle",
                color: Theme.textSecondary
            )

            CompactStatItem(
                label: "K/D",
                value: String(format: "%.2f", classStats.kdRatio),
                icon: "chart.line.uptrend.xyaxis",
                color: classStats.kdRatio >= 1.0 ? Theme.bf6Green : Theme.bf6Orange
            )

            CompactStatItem(
                label: "Score",
                value: classStats.score.formatted(.number.notation(.compactName)),
                icon: "star.fill",
                color: .yellow
            )
        }
    }
    
    // MARK: - Expanded Stats

    private var expandedStats: some View {
        VStack(spacing: 16) {
            // Primary Stats
            HStack(spacing: 20) {
                ExpandedStatCircle(
                    value: classStats.kills,
                    label: "Kills",
                    color: Theme.bf6Red
                )

                ExpandedStatCircle(
                    value: classStats.deaths,
                    label: "Deaths",
                    color: Theme.textSecondary
                )

                VStack(spacing: 4) {
                    Text(String(format: "%.2f", classStats.kdRatio))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(classStats.kdRatio >= 1.0 ? Theme.bf6Green : Theme.bf6Orange)

                    Text("K/D Ratio")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Divider()
                .background(Theme.borderColor)
            
            // Secondary Stats
            VStack(spacing: 10) {
                DetailStatRow(
                    label: "Score per Minute",
                    value: String(format: "%.0f", classStats.scorePerMinute),
                    icon: "chart.bar.fill"
                )
                
                DetailStatRow(
                    label: "Total Score",
                    value: classStats.score.formatted(),
                    icon: "star.fill"
                )
                
                DetailStatRow(
                    label: "Signature Gadget",
                    value: bf6Class.signatureGadget,
                    icon: "wrench.fill"
                )
                
                DetailStatRow(
                    label: "Signature Weapon",
                    value: bf6Class.signatureWeaponType,
                    icon: "scope"
                )
            }
        }
    }
    
    // MARK: - Background

    private var tileBackground: some View {
        ZStack {
            // Base gradient - uses adaptive background color
            LinearGradient(
                colors: [
                    bf6Class.color.opacity(0.3),
                    Theme.backgroundPrimary.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Glass effect
            Theme.overlayColor

            // Noise texture overlay
            GeometryReader { geo in
                Image(systemName: "circle.grid.3x3.fill")
                    .resizable()
                    .frame(width: geo.size.width * 2, height: geo.size.height * 2)
                    .foregroundColor(Theme.overlayColor)
                    .offset(x: -geo.size.width / 2, y: -geo.size.height / 2)
            }
        }
    }
    
    // MARK: - Overlay
    
    private var tileOverlay: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [
                        bf6Class.color.opacity(isHovered ? 0.8 : 0.5),
                        bf6Class.color.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Compact Stat Item

struct CompactStatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Expanded Stat Circle

struct ExpandedStatCircle: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 3)
                    .frame(width: 60, height: 60)

                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Detail Stat Row

struct DetailStatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Theme.bf6Orange)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Theme.backgroundPrimary.ignoresSafeArea()

        ClassTileView(
            classStats: ClassStats(
                className: "Assault",
                timePlayed: 36000,
                kills: 1250,
                deaths: 890,
                kdRatio: 1.40,
                score: 125000,
                scorePerMinute: 450,
                image: nil
            ),
            position: TilePosition(x: 200, y: 200),
            onPositionChange: { _ in }
        )
    }
    .frame(width: 600, height: 500)
}
