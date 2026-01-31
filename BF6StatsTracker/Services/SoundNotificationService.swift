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
//  SoundNotificationService.swift
//  BF6StatsTracker
//
//  Provides sound notifications for match completion events
//

import Foundation
import AppKit

/// Service for playing sound notifications
@MainActor
class SoundNotificationService: ObservableObject {
    static let shared = SoundNotificationService()

    private init() {}

    /// Play a sound when a match is completed and snapshot is saved
    func playMatchCompletionSound(settings: AppSettings) {
        // Only play sound if the user has enabled it in settings
        guard settings.playSoundOnSnapshot else { return }

        // Use the user's selected sound, defaulting to "Glass" if not set or invalid
        let soundName = settings.selectedSound.isEmpty ? "Glass" : settings.selectedSound
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}
