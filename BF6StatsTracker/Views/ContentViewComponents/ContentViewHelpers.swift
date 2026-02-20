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
//  ContentViewHelpers.swift
//  BF6StatsTracker
//
//  Helper functions and utilities for ContentView
//

import Foundation

// MARK: - Formatting Functions

/// Format XP numbers with K/M suffixes
func formatXP(_ xp: Int) -> String {
    if xp >= 1_000_000 {
        return String(format: "%.1fM", Double(xp) / 1_000_000.0)
    } else if xp >= 1_000 {
        return String(format: "%.1fK", Double(xp) / 1_000.0)
    } else {
        return "\(xp)"
    }
}

/// Format kills with comma separators
func formatKills(_ kills: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: kills)) ?? "\(kills)"
}
