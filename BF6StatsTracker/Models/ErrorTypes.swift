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
//  ErrorTypes.swift
//  BF6StatsTracker
//
//  Error type definitions for the application
//

import Foundation

// MARK: - Error Types
enum BF6TrackerError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case playerNotFound
    case rateLimited
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .playerNotFound:
            return "Player not found. Please check the username and platform."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (code: \(code)). Please try again later."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
