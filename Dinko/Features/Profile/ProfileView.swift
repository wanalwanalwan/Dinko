import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.authViewModel) private var authViewModel
    @State private var viewModel = ProfileViewModel()
    @State private var duprService = DUPRService.shared
    @State private var showDUPRConnect = false
    @State private var showDUPRStats = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    duprSection
                    playerProfileSection
                    trainingSection
                    accountSection
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
    }

    // MARK: - DUPR Section

    private var duprSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("DUPR RATING")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            if duprService.isConnected, let profile = duprService.profile {
                connectedDUPRCard(profile)
            } else {
                disconnectedDUPRCard
            }
        }
        .sheet(isPresented: $showDUPRConnect) {
            NavigationStack {
                DUPRConnectSheet(duprService: duprService)
                    .navigationTitle("Connect DUPR")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showDUPRConnect = false }
                                .foregroundStyle(AppColors.primary)
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDUPRStats) {
            DUPRStatsView()
        }
    }

    private func connectedDUPRCard(_ profile: DUPRProfile) -> some View {
        VStack(spacing: 0) {
            Button {
                showDUPRStats = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppColors.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected · ID \(profile.duprId)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        HStack(spacing: 10) {
                            Text("S \(profile.formattedSingles)")
                            Text("D \(profile.formattedDoubles)")
                        }
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Stats")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, AppSpacing.md)

            Button {
                duprService.disconnect()
            } label: {
                HStack {
                    Label("Disconnect DUPR", systemImage: "link.slash")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
        }
        .floatingCard()
    }

    private var disconnectedDUPRCard: some View {
        Button {
            showDUPRConnect = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 17))
                        .foregroundStyle(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect DUPR Account")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Sync your official pickleball rating")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .floatingCard()
    }

    // MARK: - Player Profile Section

    private var playerProfileSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("PLAYER PROFILE")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 0) {
                profileRow(title: "DUPR Level", value: viewModel.duprRange, options: [
                    "Beginner (2.0-3.0)", "Intermediate (3.0-4.0)", "Advanced (4.0-5.0)", "Pro (5.0+)"
                ]) { viewModel.duprRange = $0; viewModel.save() }

                Divider().padding(.leading, AppSpacing.md)

                profileRow(title: "Play Style", value: viewModel.playStyle, options: [
                    "Banger", "Dinker", "All-Court", "Counter-Puncher"
                ]) { viewModel.playStyle = $0; viewModel.save() }

                Divider().padding(.leading, AppSpacing.md)

                profileRow(title: "Game Format", value: viewModel.gameFormat, options: [
                    "Singles", "Doubles", "Both"
                ]) { viewModel.gameFormat = $0; viewModel.save() }

                Divider().padding(.leading, AppSpacing.md)

                profileRow(title: "Goal", value: viewModel.primaryGoal, options: [
                    "Compete in tournaments", "Improve DUPR", "Stay active", "Beat my friends"
                ]) { viewModel.primaryGoal = $0; viewModel.save() }

                Divider().padding(.leading, AppSpacing.md)

                profileRow(title: "Age Range", value: viewModel.ageRange, options: [
                    "Under 30", "30-50", "50+"
                ]) { viewModel.ageRange = $0; viewModel.save() }
            }
            .floatingCard()
        }
    }

    // MARK: - Training Section

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("TRAINING")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 0) {
                profileRow(title: "Weekly Goal", value: weeklyGoalDisplayValue, options: [
                    "1-2x / week", "3-4x / week", "5+ / week"
                ]) { selected in
                    switch selected {
                    case "1-2x / week": viewModel.weeklyGoal = 2
                    case "3-4x / week": viewModel.weeklyGoal = 4
                    case "5+ / week": viewModel.weeklyGoal = 5
                    default: break
                    }
                    viewModel.save()
                }

                Divider().padding(.leading, AppSpacing.md)

                drillPreferencesRow
            }
            .floatingCard()
        }
    }

    private var weeklyGoalDisplayValue: String? {
        guard let goal = viewModel.weeklyGoal else { return nil }
        switch goal {
        case 1...2: return "1-2x / week"
        case 3...4: return "3-4x / week"
        default: return "5+ / week"
        }
    }

    private var drillPreferencesRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack {
                Text("Drill Preferences")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            let types = ["Fitness", "Court IQ", "Technique", "Mental Game"]
            FlowLayout(spacing: AppSpacing.xxs) {
                ForEach(types, id: \.self) { type in
                    Button {
                        if viewModel.drillPreferences.contains(type) {
                            viewModel.drillPreferences.remove(type)
                        } else {
                            viewModel.drillPreferences.insert(type)
                        }
                        viewModel.save()
                    } label: {
                        Text(type)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(viewModel.drillPreferences.contains(type) ? .white : AppColors.textPrimary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xxxs)
                            .background(viewModel.drillPreferences.contains(type) ? AppColors.primary : AppColors.background)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(viewModel.drillPreferences.contains(type) ? AppColors.primary : AppColors.separator, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("ACCOUNT")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            VStack(spacing: 0) {
                Link(destination: AppURLs.privacyPolicy) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }

                Divider().padding(.leading, AppSpacing.md)

                Link(destination: AppURLs.termsOfService) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }

                Divider().padding(.leading, AppSpacing.md)

                Button {
                    Task { await authViewModel?.signOut() }
                    dismiss()
                } label: {
                    HStack {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }

                Divider().padding(.leading, AppSpacing.md)

                Button {
                    authViewModel?.showDeleteConfirmation = true
                } label: {
                    HStack {
                        Label("Delete Account", systemImage: "trash")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
            .floatingCard()
        }
    }

    // MARK: - Helpers

    private func profileRow(
        title: String,
        value: String?,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack {
                        Text(option)
                        if option == value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(value ?? "Not set")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(value != nil ? AppColors.primary : AppColors.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    ProfileView()
}
