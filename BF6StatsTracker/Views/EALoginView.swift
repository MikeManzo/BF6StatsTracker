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
//  EALoginView.swift
//  BF6StatsTracker
//
//  EA Login view using rip-bf.com API
//

import SwiftUI

struct EALoginView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var gamerID = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EA Login")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Theme.overlayColor)

            ScrollView {
                VStack(spacing: 24) {
                    // EA Logo placeholder
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 20)

                    // Title and description
                    VStack(spacing: 8) {
                        Text("Enter Your GamerID")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Enter your EA GamerID to fetch your Battlefield 6 stats.")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Benefits
                    VStack(alignment: .leading, spacing: 12) {
                        BenefitRow(icon: "checkmark.circle.fill", text: "Quick and simple login", color: .green)
                        BenefitRow(icon: "checkmark.circle.fill", text: "No password required", color: .green)
                        BenefitRow(icon: "checkmark.circle.fill", text: "Instant stats access", color: .green)
                    }
                    .padding()
                    .background(Theme.overlayColor)
                    .cornerRadius(12)

                    // Error message
                    if let error = errorMessage ?? viewModel.eaAuthError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.error)
                            Text(error)
                                .foregroundColor(Theme.error)
                        }
                        .padding()
                        .background(Theme.error.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // GamerID Input
                    VStack(spacing: 16) {
                        TextField("Enter your GamerID", text: $gamerID)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .padding()
                            .background(Theme.overlayColor)
                            .cornerRadius(12)
                            .autocorrectionDisabled()

                        // Login button
                        Button {
                            loginWithGamerID()
                        } label: {
                            HStack {
                                if isLoading || viewModel.isAuthenticating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(Theme.selectedText)
                                } else {
                                    Image(systemName: "person.fill")
                                }
                                Text(isLoading || viewModel.isAuthenticating ? "Signing in..." : "Sign in")
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.selectedText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                gamerID.isEmpty ? 
                                LinearGradient(colors: [Theme.textSecondary], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(gamerID.isEmpty || isLoading || viewModel.isAuthenticating)
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.info)
                            Text("How It Works")
                                .font(.headline)
                        }

                        Text("Enter your EA GamerID (username) to fetch your account information. No password or authentication required.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)

                        Text("Your GamerID is your public EA username.")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding()
                    .background(Theme.info.opacity(0.1))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
        .background(Theme.backgroundPrimary)
        .onChange(of: viewModel.isEAAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func loginWithGamerID() {
        guard !gamerID.isEmpty else {
            errorMessage = "Please enter a valid GamerID"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await viewModel.authenticateWithGamerID(gamerID: gamerID)
            isLoading = false
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    EALoginView()
        .environmentObject(StatsViewModel())
}
