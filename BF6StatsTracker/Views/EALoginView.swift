//
//  EALoginView.swift
//  BF6StatsTracker
//
//  EA Login view using EAIdentityKit web authenticator
//

import SwiftUI
import EAIdentityKit

struct EALoginView: View {
    @EnvironmentObject var viewModel: StatsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showWebAuth = false
    @State private var manualToken = ""
    @State private var showManualEntry = false

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
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.2))

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
                        Text("Sign in with EA")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Connect your EA account to automatically fetch your Battlefield 6 stats using your EA ID.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Benefits
                    VStack(alignment: .leading, spacing: 12) {
                        BenefitRow(icon: "checkmark.circle.fill", text: "Automatic EA ID detection", color: .green)
                        BenefitRow(icon: "checkmark.circle.fill", text: "Secure authentication", color: .green)
                        BenefitRow(icon: "checkmark.circle.fill", text: "No need to remember your exact username", color: .green)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)

                    // Error message
                    if let error = errorMessage ?? viewModel.eaAuthError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Login buttons
                    VStack(spacing: 16) {
                        // Web login button - opens separate auth window
                        Button {
                            showWebAuth = true
                        } label: {
                            HStack {
                                if isLoading || viewModel.isAuthenticating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "globe")
                                }
                                Text(isLoading || viewModel.isAuthenticating ? "Signing in..." : "Sign in with EA")
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || viewModel.isAuthenticating)

                        // Manual token entry toggle
                        Button {
                            withAnimation {
                                showManualEntry.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Enter token manually")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Manual token entry section
                    if showManualEntry {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Manual Token Entry")
                                .font(.headline)

                            Text("If web login doesn't work, you can manually enter your EA access token. Get it from browser dev tools at gateway.ea.com")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Paste EA access token here", text: $manualToken)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)

                            Button {
                                authenticateWithToken(manualToken)
                            } label: {
                                Text("Authenticate")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(manualToken.isEmpty ? Color.gray : Color.blue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(manualToken.isEmpty || isLoading)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }

                    // Info section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("About EA Authentication")
                                .font(.headline)
                        }

                        Text("This app uses EA's official authentication to securely identify your account. Your credentials are never stored - only a temporary access token is used.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Tokens typically expire after 1 hour and you'll need to sign in again.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        .sheet(isPresented: $showWebAuth) {
            EAWebAuthView(onTokenReceived: { token in
                showWebAuth = false
                authenticateWithToken(token)
            }, onCancel: {
                showWebAuth = false
            })
        }
        .onChange(of: viewModel.isEAAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func authenticateWithToken(_ token: String) {
        guard !token.isEmpty else {
            errorMessage = "Please enter a valid token"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            await viewModel.authenticateWithEA(token: token)
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

// MARK: - EA Web Auth View (macOS)

#if os(macOS)
import AppKit

struct EAWebAuthView: View {
    let onTokenReceived: (String) -> Void
    let onCancel: () -> Void

    @State private var isAuthenticating = false
    @State private var authError: String?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Sign in to EA")
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.black.opacity(0.2))

            Spacer()

            if isAuthenticating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text("Opening EA Login...")
                        .font(.headline)

                    Text("A login window will appear. Sign in with your EA account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if let error = authError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text("Authentication Failed")
                        .font(.headline)

                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        startAuthentication()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Ready to Sign In")
                        .font(.headline)

                    Text("Click the button below to open the EA login window.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        startAuthentication()
                    } label: {
                        Text("Open EA Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(width: 400, height: 400)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
    }

    private func startAuthentication() {
        isAuthenticating = true
        authError = nil

        // Get window on main thread
        guard let window = NSApplication.shared.keyWindow else {
            authError = "No window available for authentication"
            isAuthenticating = false
            return
        }

        // Create authenticator and start authentication
        // Must happen on main thread for UI presentation
        let webAuth = EAWebAuthenticator()

        Task {
            do {
                // This call will present modal and wait for callback
                let token = try await webAuth.authenticate(from: window)

                await MainActor.run {
                    isAuthenticating = false
                    onTokenReceived(token)
                }

            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                }
                print("❌ EA Web Auth failed: \(error.localizedDescription)")
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    EALoginView()
        .environmentObject(StatsViewModel())
}
