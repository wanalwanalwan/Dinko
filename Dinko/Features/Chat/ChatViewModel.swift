import Foundation

@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    var inputText = ""
    var isSending = false

    private let agentService = AgentService()
    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository

    // Stats
    private(set) var totalSkills = 0
    private(set) var weeklyFocusTitle: String?

    private let authService = AuthService.shared

    init(
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        drillRepository: DrillRepository
    ) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
    }

    func loadStats() async {
        do {
            let skills = try await skillRepository.fetchActive()
            totalSkills = skills.filter { $0.parentSkillId == nil }.count
        } catch {
            totalSkills = 0
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true

        // Add user bubble
        let userMessage = ChatMessage(role: .user, content: .text(text))
        messages.append(userMessage)

        // Add loading bubble
        let loadingId = UUID()
        let loadingMessage = ChatMessage(id: loadingId, role: .agent, content: .loading)
        messages.append(loadingMessage)

        do {
            // Build skill snapshots from CoreData
            let snapshots = try await buildSkillSnapshots()

            // Call the Edge Function
            let response = try await agentService.logSession(
                note: text,
                skills: snapshots,
                authToken: getAuthToken()
            )

            // Replace loading bubble with preview
            let preview = SessionPreview(
                sessionId: response.sessionId,
                extraction: response.extraction,
                skillUpdates: response.skillUpdates,
                drillRecommendations: response.drillRecommendations,
                roadmapUpdates: response.roadmapUpdates,
                subskillSuggestions: response.subskillSuggestions,
                skillSuggestions: response.skillSuggestions
            )

            replaceMessage(id: loadingId, with: ChatMessage(
                id: loadingId,
                role: .agent,
                content: .sessionPreview(preview)
            ))
        } catch {
            replaceMessage(id: loadingId, with: ChatMessage(
                id: loadingId,
                role: .agent,
                content: .error(error.localizedDescription)
            ))
        }

        isSending = false
    }

    func confirmSession(messageId: UUID) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .sessionPreview(var preview) = messages[index].content
        else { return }

        preview.confirmState = .confirming
        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .sessionPreview(preview),
            timestamp: messages[index].timestamp
        )

        do {
            _ = try await agentService.confirmSession(
                sessionId: preview.sessionId,
                roadmapUpdates: preview.roadmapUpdates,
                authToken: getAuthToken()
            )

            // Apply rating changes locally to CoreData
            for update in preview.skillUpdates {
                if let skillId = UUID(uuidString: update.skillId) {
                    let rating = SkillRating(
                        skillId: skillId,
                        rating: update.new,
                        notes: "AI session update"
                    )
                    try await skillRatingRepository.save(rating)
                }
            }

            // Save only selected drill recommendations to CoreData
            let selectedDrills = preview.selectedDrillIndices.sorted().compactMap { idx in
                idx < preview.drillRecommendations.count ? preview.drillRecommendations[idx] : nil
            }
            await saveDrills(selectedDrills)

            // Create subskills if suggested
            if let suggestions = preview.subskillSuggestions, !suggestions.isEmpty {
                await createSubskills(suggestions)
            }

            // Create new skills if suggested
            if let skillSuggestions = preview.skillSuggestions, !skillSuggestions.isEmpty {
                await createSkills(skillSuggestions)
            }

            preview.confirmState = .confirmed
            messages[index] = ChatMessage(
                id: messageId,
                role: .agent,
                content: .sessionPreview(preview),
                timestamp: messages[index].timestamp
            )

            // Add a confirmation text bubble
            messages.append(ChatMessage(
                role: .agent,
                content: .text("Session confirmed! Your skills have been updated.")
            ))

            await loadStats()
        } catch {
            preview.confirmState = .failed(error.localizedDescription)
            messages[index] = ChatMessage(
                id: messageId,
                role: .agent,
                content: .sessionPreview(preview),
                timestamp: messages[index].timestamp
            )
        }
    }

    func toggleDrill(messageId: UUID, drillIndex: Int) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .sessionPreview(var preview) = messages[index].content,
              case .pending = preview.confirmState
        else { return }

        if preview.selectedDrillIndices.contains(drillIndex) {
            preview.selectedDrillIndices.remove(drillIndex)
        } else {
            preview.selectedDrillIndices.insert(drillIndex)
        }

        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .sessionPreview(preview),
            timestamp: messages[index].timestamp
        )
    }

    func retrySession(messageId: UUID) {
        // Find the user message before the error and re-send
        guard let errorIndex = messages.firstIndex(where: { $0.id == messageId }),
              errorIndex > 0,
              case .text(let originalText) = messages[errorIndex - 1].content,
              messages[errorIndex - 1].role == .user
        else { return }

        // Remove the error message
        messages.remove(at: errorIndex)
        // Remove the original user message too — sendMessage will re-add it
        messages.remove(at: errorIndex - 1)

        inputText = originalText
        Task { await sendMessage() }
    }

    // MARK: - Private

    private func buildSkillSnapshots() async throws -> [AgentService.SkillSnapshotPayload] {
        let allSkills = try await skillRepository.fetchActive()
        let parentSkills = allSkills.filter { $0.parentSkillId == nil }
        var snapshots: [AgentService.SkillSnapshotPayload] = []

        for skill in parentSkills {
            let latest = try await skillRatingRepository.fetchLatest(skill.id)
            let children = allSkills.filter { $0.parentSkillId == skill.id }

            var subPayloads: [AgentService.SubskillPayload] = []
            for child in children {
                let childRating = try await skillRatingRepository.fetchLatest(child.id)
                subPayloads.append(AgentService.SubskillPayload(
                    id: child.id.uuidString,
                    name: child.name,
                    currentRating: childRating?.rating ?? 0
                ))
            }

            snapshots.append(AgentService.SkillSnapshotPayload(
                id: skill.id.uuidString,
                name: skill.name,
                category: skill.category.rawValue,
                currentRating: latest?.rating ?? 0,
                parentSkillId: nil,
                subskills: subPayloads
            ))
        }

        return snapshots
    }

    private func getAuthToken() -> String {
        guard let saved = authService.loadSavedSession() else { return "" }
        return saved.accessToken
    }

    private func replaceMessage(id: UUID, with message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = message
        }
    }

    private func saveDrills(_ recommendations: [DrillRecommendation]) async {
        do {
            let allSkills = try await skillRepository.fetchActive()

            for rec in recommendations {
                // Resolve target skill name to UUID
                guard let skill = allSkills.first(where: {
                    $0.name.lowercased() == rec.targetSkill.lowercased()
                }) else { continue }

                let drill = Drill(
                    skillId: skill.id,
                    name: rec.name,
                    drillDescription: rec.description,
                    targetSubskill: rec.targetSubskill,
                    durationMinutes: rec.durationMinutes,
                    playerCount: rec.playerCount ?? 1,
                    equipment: rec.equipment ?? "",
                    reason: rec.reason,
                    priority: rec.priority
                )
                try await drillRepository.save(drill)
            }
        } catch {
            // Drill save failure is non-critical; don't block confirm
        }
    }

    private func createSubskills(_ suggestions: [SubskillSuggestion]) async {
        do {
            for suggestion in suggestions {
                guard let parentId = UUID(uuidString: suggestion.parentSkillId) else { continue }

                // Create the subskill
                let subskill = Skill(
                    name: suggestion.name,
                    parentSkillId: parentId,
                    hierarchyLevel: 1,
                    description: suggestion.description
                )
                try await skillRepository.save(subskill)

                // Save initial rating if provided
                if suggestion.suggestedRating > 0 {
                    let rating = SkillRating(
                        skillId: subskill.id,
                        rating: suggestion.suggestedRating,
                        notes: "Initial AI-suggested rating"
                    )
                    try await skillRatingRepository.save(rating)
                }

                // Update parent to auto-calculate
                if var parent = try await skillRepository.fetchById(parentId) {
                    parent.autoCalculateRating = true
                    parent.updatedAt = Date()
                    try await skillRepository.save(parent)
                }
            }
        } catch {
            // Subskill creation failure is non-critical
        }
    }

    private func createSkills(_ suggestions: [SkillCreationSuggestion]) async {
        do {
            for suggestion in suggestions {
                let category = SkillCategory(rawValue: suggestion.category) ?? .strategy

                let skill = Skill(
                    name: suggestion.name,
                    category: category,
                    description: suggestion.description,
                    iconName: suggestion.iconName
                )
                try await skillRepository.save(skill)

                if suggestion.suggestedRating > 0 {
                    let rating = SkillRating(
                        skillId: skill.id,
                        rating: suggestion.suggestedRating,
                        notes: "Initial AI-suggested rating"
                    )
                    try await skillRatingRepository.save(rating)
                }
            }
        } catch {
            // Skill creation failure is non-critical
        }
    }
}
