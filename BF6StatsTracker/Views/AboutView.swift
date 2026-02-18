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
//  AboutView.swift
//  BF6StatsTracker
//
//  Professional About view with credits and acknowledgements
//

import SwiftUI

struct AboutView: View {
    @Environment(\.accentColor) private var accentColor
    @Environment(\.dismiss) private var dismiss

    // Get app version and build number from Info.plist
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Section
                VStack(spacing: 12) {
                    // App Icon
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 4) {
                        Text("BF6 Stats Tracker")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)

                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.top, 20)

                Divider()
                    .padding(.vertical, 4)

                // Designed & Built By
                VStack(spacing: 8) {
                    Text("Designed & Built By")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    VStack(spacing: 2) {
                        Text("CitizenCoder")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentColor, Theme.bf6Red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("2025")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Theme.overlayColor)
                .cornerRadius(10)

                Divider()
                    .padding(.vertical, 4)

                // Copyright Section
                VStack(spacing: 12) {
                    Text("Copyright & Licenses")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        CopyrightRow(
                            title: "BF6 Stats Tracker",
                            copyright: "© 2025 CitizenCoder",
                            license: "All Rights Reserved"
                        )

                        CopyrightRow(
                            title: "Battlefield™ 6",
                            copyright: "© 2024 Electronic Arts Inc.",
                            license: "EA and Battlefield are trademarks of Electronic Arts Inc."
                        )

                        CopyrightRow(
                            title: "PlayStation®",
                            copyright: "© Sony Interactive Entertainment Inc.",
                            license: "PlayStation and the PlayStation logos are registered trademarks of Sony Interactive Entertainment Inc."
                        )

                        CopyrightRow(
                            title: "Xbox®",
                            copyright: "© Microsoft Corporation",
                            license: "Xbox and the Xbox logos are trademarks of the Microsoft group of companies."
                        )
                        
                        CopyrightRow(
                            title: "iCloud®",
                            copyright: "© Apple Inc.",
                            license: "iCloud is a registered trademark of Apple Inc."
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Theme.overlayColor)
                .cornerRadius(10)

                Divider()
                    .padding(.vertical, 4)

                // API Acknowledgements
                VStack(spacing: 12) {
                    Text("API & Services")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 12) {
                        APIAcknowledgement(
                            name: "GameTools.Network API",
                            description: "Provides comprehensive Battlefield 6 player statistics, match history, and game data.",
                            icon: "network",
                            color: .blue
                        )

                        Divider()

                        APIAcknowledgement(
                            name: "rip-bf.com API",
                            description: "Provides EA account authentication and player identity services.",
                            icon: "person.badge.key.fill",
                            color: .green
                        )

                        Divider()

                        APIAcknowledgement(
                            name: "Hugging Face",
                            description: "Hosts the Phi-3 Mini MLX model used for on-device AI coaching features.",
                            icon: "face.smiling",
                            color: .yellow
                        )
                        
                        Divider()
                        
                        APIAcknowledgement(
                            name: "iCloud",
                            description: "Apple's iCloud Key-Value Storage provides secure, automatic backup and synchronization of snapshot data across devices.",
                            icon: "icloud.fill",
                            color: .cyan
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Theme.overlayColor)
                .cornerRadius(10)

                Divider()
                    .padding(.vertical, 4)

                // Technology Stack
                VStack(spacing: 12) {
                    Text("Built With")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        TechBadge(name: "SwiftUI", icon: "swift")
                        TechBadge(name: "SwiftData", icon: "internaldrive")
                        TechBadge(name: "iCloud", icon: "icloud.fill")
                        TechBadge(name: "macOS", icon: "apple.logo")
                        TechBadge(name: "Combine", icon: "arrow.triangle.merge")
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Theme.overlayColor)
                .cornerRadius(10)

                Divider()
                    .padding(.vertical, 4)

                // Special Thanks
                VStack(spacing: 12) {
                    Text("Special Thanks")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 8) {
                        ThanksRow(
                            icon: "globe",
                            text: "GameTools.Network team for maintaining public API access"
                        )

                        ThanksRow(
                            icon: "person.2.fill",
                            text: "Battlefield community for continued support and feedback"
                        )

                        ThanksRow(
                            icon: "hammer.fill",
                            text: "All open-source contributors and developers"
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Theme.overlayColor)
                .cornerRadius(10)

                // Disclaimer
                VStack(spacing: 8) {
                    Text("Disclaimer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    Text("BF6 Stats Tracker is an unofficial, fan-made application and is not affiliated with, endorsed by, or connected to Electronic Arts Inc. or DICE. All game content, trademarks, and copyrights are property of their respective owners.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                .background(Theme.warning.opacity(0.1))
                .cornerRadius(10)

                // Footer
                VStack(spacing: 4) {
                    Text("Made with ❤️ for the Battlefield community")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)

                    Text("2025")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.backgroundPrimary)
        .frame(width: 400, height: 700)
    }
}

// MARK: - Supporting Views

struct CopyrightRow: View {
    let title: String
    let copyright: String
    let license: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text(copyright)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)

            Text(license)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .italic()
        }
    }
}

struct APIAcknowledgement: View {
    let name: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TechBadge: View {
    let name: String
    let icon: String
    
    @Environment(\.accentColor) private var accentColor

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(accentColor)

            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(accentColor.opacity(0.1))
        .cornerRadius(6)
    }
}

struct ThanksRow: View {
    let icon: String
    let text: String
    
    @Environment(\.accentColor) private var accentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(accentColor)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}
