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
//  PercentilePopoverView.swift
//  BF6StatsTracker
//
//  Popover display for community performance percentiles
//

import SwiftUI

struct PercentilePopoverView: View {
    let statName: String
    let statValue: String
    let tier: PerformanceTier
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with stat name
            HStack {
                Image(systemName: tier.icon)
                    .foregroundColor(tier.color)
                    .font(.title3)
                Text(statName)
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Divider()
            
            // Current value
            HStack {
                Text("Your \(statName):")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text(statValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Performance tier
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance Tier")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tier.color)
                        .frame(width: 8, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier.label)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(tier.color)
                        
                        Text(tier.percentileRange)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Divider()
            
            // Disclaimer
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Text(CommunityBenchmarks.disclaimer)
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

#Preview {
    PercentilePopoverView(
        statName: "K/D Ratio",
        statValue: "2.45",
        tier: .excellent
    )
}
