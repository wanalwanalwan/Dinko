import SwiftUI

struct CoachDirectoryView: View {
    let currentUserId: UUID
    let realtimeService: RealtimeService

    @State private var coaches: [CoachProfile] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedCoach: CoachProfile?
    @Environment(\.dismiss) private var dismiss

    private let chatService = CoachChatService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    errorState(error)
                } else if coaches.isEmpty {
                    emptyState
                } else {
                    coachList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background)
            .navigationTitle("Find a Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                        .buttonStyle(.plain)
                }
            }
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .navigationDestination(item: $selectedCoach) { coach in
                CoachProfileDetailView(
                    coach: coach,
                    currentUserId: currentUserId,
                    realtimeService: realtimeService,
                    onConversationStarted: { dismiss() }
                )
            }
        }
        .presentationBackground(AppColors.background)
        .task { await load() }
    }

    // MARK: - Coach List

    private var coachList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.xs) {
                ForEach(coaches) { coach in
                    coachCard(coach)
                }
            }
            .padding(AppSpacing.md)
        }
    }

    private func coachCard(_ coach: CoachProfile) -> some View {
        Button { selectedCoach = coach } label: {
            HStack(spacing: AppSpacing.sm) {
                coachAvatar(coach, size: 54)

                VStack(alignment: .leading, spacing: 5) {
                    Text(coach.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    if let bio = coach.coachBio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    if let specialties = coach.coachSpecialties, !specialties.isEmpty {
                        specialtyRow(specialties)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func specialtyRow(_ specialties: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(specialties.prefix(4), id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func coachAvatar(_ coach: CoachProfile, size: CGFloat) -> some View {
        Circle()
            .fill(AppColors.primary.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Text(coach.initials)
                    .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            )
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
            Text("No coaches available")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Text("Check back soon!")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.coral)
            Text(message)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Load

    private func load() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            error = "Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        do {
            coaches = try await chatService.fetchCoaches(authToken: token)
        } catch let fetchError {
            error = fetchError.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Coach Profile Detail

struct CoachProfileDetailView: View {
    let coach: CoachProfile
    let currentUserId: UUID
    let realtimeService: RealtimeService
    let onConversationStarted: () -> Void

    @State private var isStarting = false
    @State private var error: String?
    @State private var createdConversation: Conversation?

    private let chatService = CoachChatService()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                heroSection
                    .padding(.top, AppSpacing.md)

                if let specialties = coach.coachSpecialties, !specialties.isEmpty {
                    specialtiesSection(specialties)
                }

                if let bio = coach.coachBio, !bio.isEmpty {
                    bioSection(bio)
                }

                Spacer(minLength: AppSpacing.xl)

                if let error {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                ctaButton
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .background(AppColors.background)
        .navigationTitle(coach.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .navigationDestination(item: $createdConversation) { conversation in
            CoachChatView(
                viewModel: CoachChatViewModel(
                    conversation: conversation,
                    currentUserId: currentUserId,
                    role: .player,
                    realtimeService: realtimeService
                )
            )
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(AppColors.primary.opacity(0.12))
                .frame(width: 88, height: 88)
                .overlay(
                    Text(coach.initials)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                )

            Text(coach.displayName)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("Pickleball Coach")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func specialtiesSection(_ specialties: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Specialties")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(specialties, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
    }

    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("About")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            Text(bio)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.md)
    }

    private var ctaButton: some View {
        Button {
            Task { await startConversation() }
        } label: {
            Group {
                if isStarting {
                    ProgressView().tint(.white)
                } else {
                    Text("Message \(coach.firstName)")
                        .font(AppTypography.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.primary)
        .disabled(isStarting)
    }

    private func startConversation() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            error = "Please sign in again."
            return
        }

        isStarting = true
        error = nil
        do {
            let conversation = try await chatService.createConversation(
                playerId: currentUserId,
                coachId: coach.id,
                authToken: token
            )
            createdConversation = conversation
            onConversationStarted()
        } catch let startError {
            error = startError.localizedDescription
        }
        isStarting = false
    }
}
