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

    // Stats
    private(set) var totalSkills = 0
    private(set) var weeklyFocusTitle: String?

    // Auth token — set from outside (Supabase Auth)
    var authToken: String = ""

    init(
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository
    ) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
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
                authToken: authToken
            )

            // Replace loading bubble with preview
            let preview = SessionPreview(
                sessionId: response.sessionId,
                extraction: response.extraction,
                skillUpdates: response.skillUpdates,
                drillRecommendations: response.drillRecommendations,
                roadmapUpdates: response.roadmapUpdates
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
                authToken: authToken
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

    private func replaceMessage(id: UUID, with message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index] = message
        }
    }
}
