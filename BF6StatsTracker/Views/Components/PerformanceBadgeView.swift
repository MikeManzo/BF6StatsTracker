//
//  PerformanceBadgeView.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI

enum PerformanceBadge {
    case onFire        // K/D > 2.0 and improving
    case hotStreak     // 3+ days of improvement
    case sharpshooter  // HS% > 50%
    case speedDemon    // KPM > 3.0
    case victoryMarch  // Win rate > 60%
    case comebackKid   // Improved after bad yesterday
    case teamPlayer    // High revives/resupplies
    case clutch        // High wins today

    var icon: String {
        switch self {
        case .onFire: return "flame.fill"
        case .hotStreak: return "chart.line.uptrend.xyaxis"
        case .sharpshooter: return "scope"
        case .speedDemon: return "bolt.fill"
        case .victoryMarch: return "trophy.fill"
        case .comebackKid: return "arrow.up.right.circle.fill"
        case .teamPlayer: return "person.3.fill"
        case .clutch: return "star.fill"
        }
    }

    var title: String {
        switch self {
        case .onFire: return "ON FIRE!"
        case .hotStreak: return "Hot Streak"
        case .sharpshooter: return "Sharpshooter"
        case .speedDemon: return "Speed Demon"
        case .victoryMarch: return "Victory March"
        case .comebackKid: return "Comeback Kid"
        case .teamPlayer: return "Team Player"
        case .clutch: return "Clutch"
        }
    }

    var color: Color {
        switch self {
        case .onFire: return .red
        case .hotStreak: return .orange
        case .sharpshooter: return .purple
        case .speedDemon: return .yellow
        case .victoryMarch: return .green
        case .comebackKid: return .blue
        case .teamPlayer: return .cyan
        case .clutch: return .pink
        }
    }

    var description: String {
        switch self {
        case .onFire: return "K/D above 2.0 and improving"
        case .hotStreak: return "3+ days of improvements"
        case .sharpshooter: return "Headshot rate over 50%"
        case .speedDemon: return "Kills per minute over 3.0"
        case .victoryMarch: return "Win rate above 60%"
        case .comebackKid: return "Bounced back strong"
        case .teamPlayer: return "Supporting the team"
        case .clutch: return "Coming through when needed"
        }
    }
}

struct PerformanceBadgeView: View {
    let badge: PerformanceBadge
    let metrics: [String]

    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [badge.color, badge.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)

                    Image(systemName: badge.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(badge.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(badge.color)

                    Text(badge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Metrics
            VStack(alignment: .leading, spacing: 6) {
                ForEach(metrics, id: \.self) { metric in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(badge.color)

                        Text(metric)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(badge.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [badge.color, badge.color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

struct PerformanceBadgesView: View {
    let today: DailyPerformance
    let yesterday: DailyPerformance?

    private var earnedBadges: [PerformanceBadge] {
        var badges: [PerformanceBadge] = []

        // On Fire: K/D > 2.0 and improving
        if today.dailyKD > 2.0 {
            if let yest = yesterday, today.dailyKD > yest.dailyKD {
                badges.append(.onFire)
            } else if yesterday == nil && today.dailyKD > 2.0 {
                badges.append(.onFire)
            }
        }

        // Sharpshooter: HS% > 50%
        if today.dailyHeadshotPercent > 50 {
            badges.append(.sharpshooter)
        }

        // Speed Demon: KPM > 3.0
        if today.dailyKPM > 3.0 {
            badges.append(.speedDemon)
        }

        // Victory March: Win rate > 60%
        if today.dailyWinRate > 60 {
            badges.append(.victoryMarch)
        }

        // Comeback Kid: Improved K/D after bad yesterday
        if let yest = yesterday, yest.dailyKD < 1.0 && today.dailyKD > yest.dailyKD + 0.3 {
            badges.append(.comebackKid)
        }

        // Team Player: High support stats
        if today.deltaRevives + today.deltaResupplies > 20 {
            badges.append(.teamPlayer)
        }

        // Clutch: High win rate today
        if today.dailyWinRate > 50 && today.deltaMatchesPlayed >= 3 {
            badges.append(.clutch)
        }

        return badges
    }

    private func metricsFor(_ badge: PerformanceBadge) -> [String] {
        switch badge {
        case .onFire:
            var metrics = [
                "K/D: \(String(format: "%.2f", today.dailyKD))",
                "\(today.deltaKills) kills today"
            ]
            if let yest = yesterday {
                metrics.append("+\(String(format: "%.2f", today.dailyKD - yest.dailyKD)) vs yesterday")
            } else {
                metrics.append("Dominating performance")
            }
            return metrics

        case .sharpshooter:
            return [
                "\(String(format: "%.1f%%", today.dailyHeadshotPercent)) headshot rate",
                "\(today.deltaHeadshots) headshots"
            ]

        case .speedDemon:
            return [
                "\(String(format: "%.1f", today.dailyKPM)) kills per minute",
                "Fast and aggressive"
            ]

        case .victoryMarch:
            return [
                "\(String(format: "%.1f%%", today.dailyWinRate)) win rate",
                "\(today.deltaWins) wins today"
            ]

        case .comebackKid:
            if let yest = yesterday {
                return [
                    "K/D improved from \(String(format: "%.2f", yest.dailyKD))",
                    "to \(String(format: "%.2f", today.dailyKD))"
                ]
            }
            return ["Strong comeback"]

        case .teamPlayer:
            return [
                "\(today.deltaRevives) revives",
                "\(today.deltaResupplies) resupplies"
            ]

        case .clutch:
            return [
                "\(today.deltaWins) wins in \(today.deltaMatchesPlayed) matches",
                "Coming through when it counts"
            ]

        case .hotStreak:
            return ["Multiple days of improvement"]
        }
    }

    var body: some View {
        if !earnedBadges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("🎖️ Performance Badges")
                    .font(.headline)
                    .fontWeight(.bold)

                ForEach(earnedBadges, id: \.title) { badge in
                    PerformanceBadgeView(badge: badge, metrics: metricsFor(badge))
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PerformanceBadgeView(
            badge: .onFire,
            metrics: [
                "K/D: 2.35",
                "45 kills today",
                "+0.25 vs yesterday"
            ]
        )
        .frame(width: 400)

        PerformanceBadgeView(
            badge: .sharpshooter,
            metrics: [
                "55.6% headshot rate",
                "25 headshots"
            ]
        )
        .frame(width: 400)
    }
    .padding()
}
