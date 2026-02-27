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
//  ExtendedProfileStats.swift
//  BF6StatsTracker
//
//  Extended statistics from profile endpoint
//

import Foundation

struct ExtendedProfileStats: Codable {
    // MARK: - Human vs Bot Combat
    let humanKills: Int
    let totalKills: Int

    var botKills: Int {
        totalKills - humanKills
    }

    var humanKillPercentage: Double {
        guard totalKills > 0 else { return 0 }
        return (Double(humanKills) / Double(totalKills)) * 100
    }

    // MARK: - Combat Style
    let adsKills: Int
    let hipfireKills: Int

    var aimingPercentage: Double {
        let total = adsKills + hipfireKills
        guard total > 0 else { return 0 }
        return (Double(adsKills) / Double(total)) * 100
    }

    // MARK: - Assist Breakdown
    let spotAssists: Int
    let suppressAssists: Int
    let smokeAssists: Int
    let flashAssists: Int
    let concussAssists: Int
    let driverAssists: Int
    let pilotAssists: Int

    // MARK: - Per-Class Performance
    let assaultKills: Int
    let assaultDeaths: Int
    let engineerKills: Int
    let engineerDeaths: Int
    let supportKills: Int
    let supportDeaths: Int
    let reconKills: Int
    let reconDeaths: Int

    var assaultKD: Double {
        guard assaultDeaths > 0 else { return Double(assaultKills) }
        return Double(assaultKills) / Double(assaultDeaths)
    }

    var engineerKD: Double {
        guard engineerDeaths > 0 else { return Double(engineerKills) }
        return Double(engineerKills) / Double(engineerDeaths)
    }

    var supportKD: Double {
        guard supportDeaths > 0 else { return Double(supportKills) }
        return Double(supportKills) / Double(supportDeaths)
    }

    var reconKD: Double {
        guard reconDeaths > 0 else { return Double(reconKills) }
        return Double(reconKills) / Double(reconDeaths)
    }

    // MARK: - Initialization from Profile Stats Array
    init(from profileStats: [ProfileStat]) {
        // Parse stats array
        func getValue(for name: String) -> Int {
            profileStats.first(where: { $0.name == name })?.value ?? 0
        }

        // Human vs Bot
        self.humanKills = getValue(for: "human_kills_total")
        self.totalKills = getValue(for: "Kills_Total")

        // Combat Style
        self.adsKills = getValue(for: "Kills_ADS_Total")
        self.hipfireKills = getValue(for: "Kills_Hipfire_Total")

        // Assist Breakdown
        self.spotAssists = getValue(for: "Spot_Assists_Enemies_Total")
        self.suppressAssists = getValue(for: "Supress_Assists_Enemies_Total")
        self.smokeAssists = getValue(for: "Smoke_Assists_Enemies_Total")
        self.flashAssists = getValue(for: "Flash_Assists_Enemies_Total")
        self.concussAssists = getValue(for: "Concuss_Assists_Enemies_Total")
        self.driverAssists = getValue(for: "Assists_Driver_Total")
        self.pilotAssists = getValue(for: "Assists_Pilot_Total")

        // Per-Class Performance
        self.assaultKills = getValue(for: "kw_kit_assault")
        self.assaultDeaths = getValue(for: "deaths_kit_assault")
        self.engineerKills = getValue(for: "kw_kit_engineer")
        self.engineerDeaths = getValue(for: "deaths_kit_engineer")
        self.supportKills = getValue(for: "kw_kit_support")
        self.supportDeaths = getValue(for: "deaths_kit_support")
        self.reconKills = getValue(for: "kw_kit_recon")
        self.reconDeaths = getValue(for: "deaths_kit_recon")
    }
}
