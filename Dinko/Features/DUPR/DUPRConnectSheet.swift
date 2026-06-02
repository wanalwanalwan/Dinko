import SwiftUI

struct DUPRConnectSheet: View {
    @Bindable var duprService: DUPRService
    var onConnected: (() -> Void)?

    @State private var showWebView = false
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        if duprService.isConnected, let profile = duprService.profile {
            connectedState(profile)
        } else {
            disconnectedState
        }
    }

    // MARK: - Disconnected State

    private var disconnectedState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Text("🎯")
                        .font(.system(size: 32))
                }

                Text("Connect DUPR")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Link your DUPR account to see your real rating and track how it changes over time.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            if let error = errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.coral)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)
            }

            VStack(spacing: AppSpacing.xs) {
                Button {
                    errorMessage = nil
                    showWebView = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                        Text("Connect DUPR Account")
                            .font(AppTypography.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, AppSpacing.lg)

                Text("You'll sign in to your DUPR account to authorize the connection.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            Spacer()
        }
        .sheet(isPresented: $showWebView) {
            duprSSOSheet
        }
    }

    // MARK: - Connected State

    private func connectedState(_ profile: DUPRProfile) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.successGreen.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(AppColors.successGreen)
                }

                Text("DUPR Connected")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Text("DUPR ID: \(profile.duprId)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: AppSpacing.lg) {
                ratingPill(
                    label: "Singles",
                    value: profile.formattedSingles,
                    provisional: profile.singlesProvisional
                )
                ratingPill(
                    label: "Doubles",
                    value: profile.formattedDoubles,
                    provisional: profile.doublesProvisional
                )
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()

            Button {
                duprService.disconnect()
            } label: {
                Text("Disconnect DUPR")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.coral)
            }
            .padding(.bottom, AppSpacing.md)
        }
    }

    private func ratingPill(label: String, value: String, provisional: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primary)
            Text(label + (provisional ? " (P)" : ""))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - SSO Sheet

    private var duprSSOSheet: some View {
        NavigationStack {
            ZStack {
                DUPRWebView(
                    onResult: { result in
                        showWebView = false
                        Task { @MainActor in
                            duprService.connectWithAuthResult(result)
                            onConnected?()
                        }
                    },
                    onError: { message in
                        showWebView = false
                        errorMessage = message
                    }
                )

                if isConnecting {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.background.opacity(0.6))
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Sign in to DUPR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showWebView = false }
                        .foregroundStyle(AppColors.primary)
                }
            }
            .toolbarBackground(AppColors.background, for: .navigationBar)
        }
    }
}
