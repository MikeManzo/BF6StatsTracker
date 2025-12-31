//
//  SessionHistoryView.swift
//  BF6StatsTracker
//
//  Displays play session history and trends
//

import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @EnvironmentObject var viewModel: StatsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                header

                // Current Session (if active)
                if let currentSession = historyManager.sessions.first(where: { $0.endTime == nil }) {
                    currentSessionCard(currentSession)
                }

                // Session Stats Summary
                sessionSummary

                // Recent Sessions
                recentSessionsList
            }
            .padding()
        }
        .background(Theme.backgroundPrimary)
    }

    private var header: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.cyan)
                .font(.title2)

            Text("Session History")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: startNewSession) {
                Label("New Session", systemImage: "play.circle")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    private func currentSessionCard(_ session: PlaySession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)

                Text("Active Session")
                    .font(.headline)

                Spacer()

                Text(formatDuration(session.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                StatBadge(label: "Kills", value: "\(session.killsGained)", color: .red)
                StatBadge(label: "Deaths", value: "\(session.deathsGained)", color: Theme.textSecondary)
                StatBadge(label: "Matches", value: "\(session.matchesPlayed)", color: .blue)
            }

            Button(action: { endCurrentSession(session) }) {
                Text("End Session")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
        .transition(.scale.combined(with: .opacity))
    }

    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            if let summary = historyManager.getPerformanceSummary(days: 7) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    SummaryCard(title: "Avg K/D", value: String(format: "%.2f", summary.averageKD), trend: summary.trend)
                    SummaryCard(title: "Best K/D", value: String(format: "%.2f", summary.maxKD), trend: nil)
                    SummaryCard(title: "Sessions", value: "\(summary.snapshotCount)", trend: nil)
                }
            } else {
                Text("Start playing to see your performance summary")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if historyManager.sessions.isEmpty {
                Text("No sessions recorded yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(historyManager.sessions.prefix(10), id: \.id) { session in
                    SessionRow(session: session)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: historyManager.sessions.count)
            }
        }
    }

    // MARK: - Actions

    private func startNewSession() {
        guard let playerName = viewModel.playerStats?.userName else { return }
        historyManager.startSession(
            playerName: playerName,
            platform: viewModel.settings.platform.rawValue
        )
    }

    private func endCurrentSession(_ session: PlaySession) {
        guard let stats = viewModel.playerStats else { return }
        historyManager.endSession(with: stats)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Supporting Views

struct SessionRow: View {
    let session: PlaySession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.startTime, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if session.endTime != nil {
                    Text(formatDuration(session.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 12) {
                StatChip(label: "K/D", value: String(format: "%.2f", session.avgKD), color: .red)
                StatChip(label: "Kills", value: "\(session.killsGained)", color: .orange)
                StatChip(label: "Matches", value: "\(session.matchesPlayed)", color: .blue)
            }
        }
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let trend: TrendDirection?

    var body: some View {
        VStack(spacing: 8) {
            if let trend = trend {
                Image(systemName: trend.icon)
                    .foregroundColor(trend.color)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.overlayColor)
        .cornerRadius(12)
    }
}

struct StatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    SessionHistoryView()
        .environmentObject(StatsViewModel())
}
