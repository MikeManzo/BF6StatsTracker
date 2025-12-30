//
//  AccountSelectionView.swift
//  BF6StatsTracker
//
//  Created by Claude on 2025-12-29.
//

import SwiftUI

struct AccountSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accountStore = EAAccountStore.shared
    @EnvironmentObject var viewModel: StatsViewModel

    @State private var selectedAccountId: UUID?
    @State private var isLoadingAccount = false
    @State private var showingLoginView = false
    @State private var accountToDelete: StoredEAAccount?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Account list
            ScrollView {
                VStack(spacing: 12) {
                    if accountStore.accounts.isEmpty {
                        emptyState
                    } else {
                        ForEach(accountStore.accounts) { account in
                            accountRow(account)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer with action button
            footer
        }
        .frame(width: 450, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingLoginView) {
            EALoginView()
                .environmentObject(viewModel)
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation,
            presenting: accountToDelete
        ) { account in
            Button("Delete", role: .destructive) {
                accountStore.deleteAccount(account)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            Text("Are you sure you want to remove \(account.displayText) from your saved accounts? You'll need to sign in again to use this account.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Choose Account")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Account Row

    private func accountRow(_ account: StoredEAAccount) -> some View {
        Button {
            selectAccount(account)
        } label: {
            HStack(spacing: 16) {
                // Account icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)

                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                // Account info
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayText)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if account.displayName != nil {
                        Text(account.eaId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Last used: \(account.lastUsedFormatted)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Selection indicator or loading
                if isLoadingAccount && selectedAccountId == account.id {
                    ProgressView()
                        .controlSize(.small)
                } else if selectedAccountId == account.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }

                // Delete button
                Button {
                    accountToDelete = account
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("Remove this account")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedAccountId == account.id ?
                          Color.accentColor.opacity(0.1) :
                          Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        selectedAccountId == account.id ?
                        Color.accentColor :
                        Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Saved Accounts")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Sign in with EA to save your account for quick access")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                showingLoginView = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Sign in with different account")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            if !accountStore.accounts.isEmpty {
                Button("Clear All Accounts") {
                    accountStore.clearAllAccounts()
                }
                .foregroundStyle(.red)
                .font(.caption)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func selectAccount(_ account: StoredEAAccount) {
        selectedAccountId = account.id
        isLoadingAccount = true

        Task {
            // Get the identity from the stored account
            let identity = accountStore.selectAccount(account)

            // Load this identity into the view model
            await viewModel.loadWithStoredIdentity(identity)

            isLoadingAccount = false

            // Dismiss the sheet
            dismiss()
        }
    }
}

#Preview {
    AccountSelectionView()
        .environmentObject(StatsViewModel())
}
