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
//  MapsPlayedCard.swift
//  BF6StatsTracker
//
//  Card showing maps played between snapshots
//

import SwiftUI
import SwiftData

struct MapsPlayedCard: View {
    @EnvironmentObject var historyManager: HistoryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Maps Played", icon: "map.fill")

            if let mapsPlayed = getMapsPlayed() {
                if mapsPlayed.isEmpty {
                    Text("No map activity detected")
                        .foregroundColor(Theme.textSecondary)
                        .font(.subheadline)
                } else if mapsPlayed.count == 1 {
                    // Single map - prominent display
                    singleMapView(mapsPlayed[0])
                } else {
                    // Multiple maps - compact list
                    multipleMapsList(mapsPlayed)
                }
            } else {
                Text("No snapshot history available")
                    .foregroundColor(Theme.textSecondary)
                    .font(.subheadline)
            }
        }
        .cardStyle()
    }

    private func getMapsPlayed() -> [MapActivity]? {
        let snapshots = historyManager.getRecentSnapshots(limit: 2)
        guard let latest = snapshots.first,
              snapshots.count >= 2 else {
            return nil
        }

        let previous = snapshots[1]
        return latest.mapsPlayedSince(previous)
    }

    private func singleMapView(_ mapActivity: MapActivity) -> some View {
        HStack(spacing: 16) {
            // Map icon
            Image(systemName: "map.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.bf6Orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(mapActivity.mapName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 16) {
                    Label("\(mapActivity.matchesPlayed) match\(mapActivity.matchesPlayed == 1 ? "" : "es")", systemImage: "flag.checkered")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Label(mapActivity.timePlayedFormatted, systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Theme.bf6Orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.bf6Orange.opacity(0.3), lineWidth: 1)
        )
    }

    private func multipleMapsList(_ maps: [MapActivity]) -> some View {
        VStack(spacing: 8) {
            ForEach(maps.prefix(5)) { mapActivity in
                HStack(spacing: 12) {
                    // Map bullet
                    Circle()
                        .fill(Theme.bf6Orange)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mapActivity.mapName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)

                        HStack(spacing: 8) {
                            Text("\(mapActivity.matchesPlayed) match\(mapActivity.matchesPlayed == 1 ? "" : "es")")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)

                            Text(mapActivity.timePlayedShort)
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    Spacer()

                    // Time badge
                    Text(mapActivity.timePlayedShort)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.bf6Orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.bf6Orange.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.vertical, 4)
            }

            if maps.count > 5 {
                Text("+ \(maps.count - 5) more map\(maps.count - 5 == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
}

#Preview {
    MapsPlayedCard()
        .padding()
        .background(Theme.backgroundPrimary)
        .environmentObject(HistoryManager.shared)
}
