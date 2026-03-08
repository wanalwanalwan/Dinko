import Foundation

@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    var inputText = ""
    var isSending = false

    private var sendTask: Task<Void, Never>?
    private let agentService = AgentService()
    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository
    private let journalEntryRepository: JournalEntryRepository

    // Stats
    private(set) var totalSkills = 0
    private(set) var weeklyFocusTitle: String?

    private let authService = AuthService.shared

    init(
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        drillRepository: DrillRepository,
        journalEntryRepository: JournalEntryRepository
    ) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
        self.journalEntryRepository = journalEntryRepository
    }

    func loadStats() async {
        do {
            let skills = try await skillRepository.fetchActive()
            totalSkills = skills.filter { $0.parentSkillId == nil }.count
        } catch {
            totalSkills = 0
        }
    }

    func send() {
        sendTask = Task { await sendMessage() }
    }

    func cancelSending() {
        sendTask?.cancel()
        sendTask = nil

        // Remove the loading bubble if present
        if let lastAgent = messages.last, lastAgent.role == .agent, case .loading = lastAgent.content {
            messages.removeLast()
        }

        // Remove the preceding user message and restore its text
        if let lastUser = messages.last, lastUser.role == .user, case .text(let original) = lastUser.content {
            messages.removeLast()
            inputText = original
        }

        isSending = false
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true

        // Add user bubble
        let userMessage = ChatMessage(role: .user, content: .text(text))
        messages.append(userMessage)

        // Check for skill creation intent before calling edge function
        if let creationPreview = await detectSkillCreationIntent(text) {
            let creationMessage = ChatMessage(role: .agent, content: .skillCreation(creationPreview))
            messages.append(creationMessage)
            isSending = false
            return
        }

        // Check for deletion intent before calling edge function
        if let matchedSkill = await detectDeletionIntent(text) {
            let subskills = await fetchSubskillNames(for: matchedSkill.id)
            let preview = SkillDeletionPreview(
                skillId: matchedSkill.id,
                skillName: matchedSkill.name,
                subskillNames: subskills,
                confirmState: .pending
            )
            let deletionMessage = ChatMessage(role: .agent, content: .skillDeletion(preview))
            messages.append(deletionMessage)
            isSending = false
            return
        }

        // Add loading bubble
        let loadingId = UUID()
        let loadingMessage = ChatMessage(id: loadingId, role: .agent, content: .loading)
        messages.append(loadingMessage)

        do {
            // Build skill snapshots from CoreData
            let snapshots = try await buildSkillSnapshots()

            // Build contextual note with conversation history for follow-ups
            let note = messages.count > 1 ? buildContextualNote(text) : text

            // Call the Edge Function
            let response = try await agentService.logSession(
                note: note,
                skills: snapshots,
                authToken: getAuthToken()
            )

            // Check if this is a general chat response (no session)
            if let chatReply = response.chatResponse, !chatReply.isEmpty {
                replaceMessage(id: loadingId, with: ChatMessage(
                    id: loadingId,
                    role: .agent,
                    content: .text(chatReply)
                ))
            } else {
                // Map saturated skills from response
                let saturated = (response.saturatedSkills ?? []).map {
                    SaturatedSkillInfo(skillName: $0.skillName, pendingCount: $0.pendingCount)
                }

                // Replace loading bubble with preview
                let preview = SessionPreview(
                    sessionId: response.sessionId ?? "",
                    extraction: response.extraction,
                    coachInsight: response.coachInsight,
                    skillUpdates: response.skillUpdates,
                    drillRecommendations: response.drillRecommendations,
                    roadmapUpdates: response.roadmapUpdates,
                    subskillSuggestions: response.subskillSuggestions,
                    skillSuggestions: response.skillSuggestions,
                    saturatedSkills: saturated
                )

                replaceMessage(id: loadingId, with: ChatMessage(
                    id: loadingId,
                    role: .agent,
                    content: .sessionPreview(preview)
                ))
            }
        } catch {
            if Task.isCancelled { return }
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
                authToken: getAuthToken()
            )

            for updateIndex in preview.selectedSkillUpdateIndices.sorted() {
                guard updateIndex < preview.skillUpdates.count else { continue }
                let update = preview.skillUpdates[updateIndex]
                if let skillId = UUID(uuidString: update.skillId) {
                    let effective = preview.effectiveSkillValues(for: updateIndex)
                    let rating = SkillRating(
                        skillId: skillId,
                        rating: effective.new,
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

            // Save journal entry — find the user message that triggered this session
            let userNote = findUserNote(before: index)
            await saveJournalEntry(from: preview, userNote: userNote)

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

    func toggleSkillUpdate(messageId: UUID, skillUpdateIndex: Int) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .sessionPreview(var preview) = messages[index].content,
              case .pending = preview.confirmState
        else { return }

        if preview.selectedSkillUpdateIndices.contains(skillUpdateIndex) {
            preview.selectedSkillUpdateIndices.remove(skillUpdateIndex)
        } else {
            preview.selectedSkillUpdateIndices.insert(skillUpdateIndex)
        }

        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .sessionPreview(preview),
            timestamp: messages[index].timestamp
        )
    }

    func toggleSubskillDelta(messageId: UUID, skillUpdateIndex: Int, subskillIndex: Int) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .sessionPreview(var preview) = messages[index].content,
              case .pending = preview.confirmState
        else { return }

        if preview.selectedSubskillIndices[skillUpdateIndex] == nil {
            let update = preview.skillUpdates[skillUpdateIndex]
            preview.selectedSubskillIndices[skillUpdateIndex] = Set(update.subskillDeltas.indices)
        }

        if preview.selectedSubskillIndices[skillUpdateIndex]!.contains(subskillIndex) {
            preview.selectedSubskillIndices[skillUpdateIndex]!.remove(subskillIndex)
        } else {
            preview.selectedSubskillIndices[skillUpdateIndex]!.insert(subskillIndex)
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
        send()
    }

    func confirmDeletion(messageId: UUID) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .skillDeletion(var preview) = messages[index].content
        else { return }

        preview.confirmState = .confirming
        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .skillDeletion(preview),
            timestamp: messages[index].timestamp
        )

        do {
            // Fetch and delete subskills first
            let allSkills = try await skillRepository.fetchActive()
            let subskills = allSkills.filter { $0.parentSkillId == preview.skillId }
            for subskill in subskills {
                try await skillRepository.delete(subskill.id)
            }
            // Delete the parent skill
            try await skillRepository.delete(preview.skillId)

            preview.confirmState = .confirmed
            messages[index] = ChatMessage(
                id: messageId,
                role: .agent,
                content: .skillDeletion(preview),
                timestamp: messages[index].timestamp
            )

            messages.append(ChatMessage(
                role: .agent,
                content: .text("Done! \(preview.skillName) has been deleted.")
            ))

            await loadStats()
        } catch {
            preview.confirmState = .failed(error.localizedDescription)
            messages[index] = ChatMessage(
                id: messageId,
                role: .agent,
                content: .skillDeletion(preview),
                timestamp: messages[index].timestamp
            )
        }
    }

    func cancelDeletion(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .skillDeletion(let preview) = messages[index].content
        else { return }

        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .text("No problem, \(preview.skillName) was not deleted."),
            timestamp: messages[index].timestamp
        )
    }

    func confirmSkillCreation(messageId: UUID) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .skillCreation(var preview) = messages[index].content
        else { return }

        preview.confirmState = .confirming
        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .skillCreation(preview),
            timestamp: messages[index].timestamp
        )

        do {
            let skill = Skill(
                name: preview.skillName,
                category: preview.category,
                iconName: preview.category.iconName
            )
            try await skillRepository.save(skill)

            preview.confirmState = .confirmed
            messages[index] = ChatMessage(
                id: messageId,
                role: .agent,
                content: .skillCreation(preview),
                timestamp: messages[index].timestamp
            )

            messages.append(ChatMessage(
                role: .agent,
                content: .text("\(preview.skillName) has been added to your skills!")
            ))

            await loadStats()
        } catch {
            preview.confirmState = .failed(error.localizedDescription)
            messages[index] = ChatMessage(
                id: messageId,
                role: .agent,
                content: .skillCreation(preview),
                timestamp: messages[index].timestamp
            )
        }
    }

    func cancelSkillCreation(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .skillCreation(let preview) = messages[index].content
        else { return }

        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .text("No problem, \(preview.skillName) was not added."),
            timestamp: messages[index].timestamp
        )
    }

    func updateSkillCreationCategory(messageId: UUID, category: SkillCategory) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              case .skillCreation(var preview) = messages[index].content,
              case .pending = preview.confirmState
        else { return }

        preview.category = category
        messages[index] = ChatMessage(
            id: messageId,
            role: .agent,
            content: .skillCreation(preview),
            timestamp: messages[index].timestamp
        )
    }

    // MARK: - Private

    private func buildContextualNote(_ currentText: String) -> String {
        var lines: [String] = []

        if let prefs = UserDefaults.standard.stringArray(forKey: "dinko_drill_preferences"), !prefs.isEmpty {
            lines.append("User's drill type preferences: \(prefs.joined(separator: ", ")).")
        }

        for message in messages {
            switch (message.role, message.content) {
            case (.user, .text(let text)):
                lines.append("User: \(text)")

            case (.agent, .sessionPreview(let preview)):
                var parts: [String] = []
                for update in preview.skillUpdates {
                    let sign = update.delta >= 0 ? "+" : ""
                    parts.append("\(update.skill) from \(update.old)% to \(update.new)% (\(sign)\(update.delta)%)")
                }
                if !parts.isEmpty {
                    lines.append("Coach: Suggested \(parts.joined(separator: "; "))")
                }
                let drillNames = preview.drillRecommendations.map(\.name)
                if !drillNames.isEmpty {
                    lines.append("Coach: Recommended drills: \(drillNames.joined(separator: ", "))")
                }

            case (.agent, .skillDeletion(let preview)):
                switch preview.confirmState {
                case .confirmed:
                    lines.append("Coach: Deleted skill \(preview.skillName)")
                case .pending, .confirming:
                    lines.append("Coach: Asked to confirm deletion of \(preview.skillName)")
                default:
                    break
                }

            case (.agent, .skillCreation(let preview)):
                switch preview.confirmState {
                case .confirmed:
                    lines.append("Coach: Created skill \(preview.skillName) (\(preview.category.displayName))")
                case .pending, .confirming:
                    lines.append("Coach: Asked to confirm creation of \(preview.skillName)")
                default:
                    break
                }

            case (.agent, .text(let text)):
                lines.append("Coach: \(text)")

            default:
                break
            }
        }

        lines.append("User: \(currentText)")

        let joined = lines.joined(separator: "\n")
        if joined.count > 4000 {
            return String(joined.suffix(4000))
        }
        return joined
    }

    private func buildSkillSnapshots() async throws -> [AgentService.SkillSnapshotPayload] {
        let allSkills = try await skillRepository.fetchActive()
        let parentSkills = allSkills.filter { $0.parentSkillId == nil }
        let allDrills = try await drillRepository.fetchAll()
        let pendingDrills = allDrills.filter { $0.status == .pending }
        var snapshots: [AgentService.SkillSnapshotPayload] = []

        for skill in parentSkills {
            let latest = try await skillRatingRepository.fetchLatest(skill.id)
            let children = allSkills.filter { $0.parentSkillId == skill.id }
            let childIds = Set(children.map(\.id))

            // Count pending drills for this skill tree (parent + all children)
            let pendingCount = pendingDrills.filter { drill in
                drill.skillId == skill.id || childIds.contains(drill.skillId)
            }.count

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
                subskills: subPayloads,
                pendingDrillCount: pendingCount
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

    private func detectSkillCreationIntent(_ text: String) async -> SkillCreationPreview? {
        let lower = text.lowercased()

        let intentKeywords = [
            "add a new skill", "add a skill", "add skill",
            "create a new skill", "create a skill", "create skill",
            "new skill", "start tracking"
        ]

        guard intentKeywords.contains(where: { lower.contains($0) }) else { return nil }

        let sessionKeywords = [
            "played", "practiced", "drilled", "session",
            "today", "yesterday", "was more consistent",
            "got better", "struggled with",
            "worked on", "working on", "focused on",
            "improved", "improving", "progress on",
            "training", "hitting", "tried"
        ]
        if sessionKeywords.contains(where: { lower.contains($0) }) { return nil }

        let skillName = extractSkillName(from: lower, original: text)
        guard !skillName.isEmpty else { return nil }

        do {
            let existingSkills = try await skillRepository.fetchActive()
            let extractedLower = skillName.lowercased()

            let fuzzyMatch = existingSkills.contains { existing in
                let existingLower = existing.name.lowercased()
                return existingLower == extractedLower
                    || existingLower.contains(extractedLower)
                    || extractedLower.contains(existingLower)
            }
            guard !fuzzyMatch else { return nil }
        } catch {
            return nil
        }

        let category = guessCategory(from: skillName)
        return SkillCreationPreview(
            skillName: skillName,
            category: category,
            confirmState: .pending
        )
    }

    private func extractSkillName(from lower: String, original: String) -> String {
        let prefixes = [
            "start tracking ",
            "add a new skill for ", "add a new skill called ", "add a new skill ",
            "add a skill for ", "add a skill called ", "add a skill ",
            "add skill for ", "add skill called ", "add skill ",
            "create a new skill for ", "create a new skill called ", "create a new skill ",
            "create a skill for ", "create a skill called ", "create a skill ",
            "create skill for ", "create skill called ", "create skill ",
            "new skill for ", "new skill called ", "new skill "
        ]

        var extracted = lower
        var matched = false
        for prefix in prefixes {
            if extracted.hasPrefix(prefix) {
                extracted = String(extracted.dropFirst(prefix.count))
                matched = true
                break
            }
        }

        if !matched { return "" }

        let suffixes = [" skill", " skills", " please", " for me"]
        for suffix in suffixes {
            if extracted.hasSuffix(suffix) {
                extracted = String(extracted.dropLast(suffix.count))
            }
        }

        extracted = extracted.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))

        guard !extracted.isEmpty else { return "" }

        return extracted.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private func guessCategory(from name: String) -> SkillCategory {
        let lower = name.lowercased()
        if lower.contains("dink") { return .dinking }
        if lower.contains("drop") { return .drops }
        if lower.contains("drive") { return .drives }
        if lower.contains("serve") || lower.contains("return") { return .serves }
        if lower.contains("block") || lower.contains("reset") || lower.contains("defend") { return .defense }
        if lower.contains("attack") || lower.contains("smash") || lower.contains("speed") || lower.contains("put away") { return .offense }
        if lower.contains("stack") || lower.contains("position") || lower.contains("transition") { return .strategy }
        return .strategy
    }

    private func detectDeletionIntent(_ text: String) async -> Skill? {
        let lower = text.lowercased()
        guard lower.contains("delete") || lower.contains("remove") else { return nil }

        do {
            let allSkills = try await skillRepository.fetchActive()
            let parentSkills = allSkills.filter { $0.parentSkillId == nil }

            // Prefer longest name match to avoid false positives
            let match = parentSkills
                .filter { lower.contains($0.name.lowercased()) }
                .max(by: { $0.name.count < $1.name.count })

            return match
        } catch {
            return nil
        }
    }

    private func fetchSubskillNames(for skillId: UUID) async -> [String] {
        do {
            let allSkills = try await skillRepository.fetchActive()
            return allSkills
                .filter { $0.parentSkillId == skillId }
                .map(\.name)
        } catch {
            return []
        }
    }

    private func findUserNote(before index: Int) -> String {
        for i in stride(from: index - 1, through: 0, by: -1) {
            if messages[i].role == .user, case .text(let text) = messages[i].content {
                return text
            }
        }
        return ""
    }

    private func saveJournalEntry(from preview: SessionPreview, userNote: String) async {
        let selectedUpdates = preview.selectedSkillUpdateIndices.sorted().compactMap { idx in
            idx < preview.skillUpdates.count ? preview.skillUpdates[idx] : nil
        }
        let skillSummary = selectedUpdates.map { update in
            let sign = update.delta >= 0 ? "+" : ""
            return "\(update.skill)|\(update.old)|\(update.new)|\(sign)\(update.delta)"
        }.joined(separator: "\n")

        let selectedDrills = preview.selectedDrillIndices.sorted().compactMap { idx in
            idx < preview.drillRecommendations.count ? preview.drillRecommendations[idx] : nil
        }
        let drillSummary = selectedDrills.map(\.name).joined(separator: ", ")

        let entry = JournalEntry(
            sessionId: preview.sessionId,
            date: Date(),
            sessionType: preview.extraction.sessionType,
            durationMinutes: preview.extraction.sessionDurationMinutes ?? 0,
            userNote: userNote,
            coachInsight: preview.coachInsight ?? "",
            skillUpdatesSummary: skillSummary,
            skillUpdatesCount: selectedUpdates.count,
            drillsCount: selectedDrills.count,
            drillNamesSummary: drillSummary
        )

        do {
            try await journalEntryRepository.save(entry)
        } catch {
            // Journal save failure is non-critical
        }
    }
}
