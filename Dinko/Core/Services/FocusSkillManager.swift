import Foundation
import Observation

// MARK: - Models

struct FocusSkillEntry: Codable, Identifiable {
    var id: UUID           // CoreData skill ID
    var name: String
    var icon: String
    var categoryRaw: String
    var priorityIndex: Int // 0, 1, 2
    var startingRating: Int? // only set for inline-created skills
}

struct PendingFocusSkill: Codable, Identifiable {
    var id: UUID = UUID()  // temporary; replaced with CoreData ID on creation
    var name: String
    var icon: String
    var categoryRaw: String
    var priorityIndex: Int
}

struct SkillIdea: Codable, Identifiable {
    var id: UUID
    var name: String
    var notes: String
    var createdAt: Date

    init(name: String, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.createdAt = Date()
    }
}

// MARK: - Manager

@MainActor
@Observable
final class FocusSkillManager {
    static let shared = FocusSkillManager()

    private(set) var focusSkills: [FocusSkillEntry] = []
    private(set) var currentFocusIndex: Int = 0
    private(set) var skillIdeas: [SkillIdea] = []

    var hasFocusSkills: Bool { !focusSkills.isEmpty }
    var isAllDone: Bool { currentFocusIndex >= focusSkills.count && !focusSkills.isEmpty }

    var currentFocusSkill: FocusSkillEntry? {
        guard currentFocusIndex < focusSkills.count else { return nil }
        return focusSkills[currentFocusIndex]
    }

    var nextFocusSkill: FocusSkillEntry? {
        let next = currentFocusIndex + 1
        guard next < focusSkills.count else { return nil }
        return focusSkills[next]
    }

    var isOnLastSkill: Bool {
        focusSkills.isEmpty || currentFocusIndex >= focusSkills.count - 1
    }

    private let focusKey   = "pkkl_focus_skill_entries"
    private let indexKey   = "pkkl_focus_skill_index"
    private let ideasKey   = "pkkl_skill_ideas"
    static let pendingKey  = "pkkl_focus_skills_pending"

    private init() { load() }

    // MARK: - Focus skill actions

    func advanceToNext() {
        guard !isOnLastSkill else { return }
        currentFocusIndex += 1
        UserDefaults.standard.set(currentFocusIndex, forKey: indexKey)
    }

    func setFocusSkills(_ entries: [FocusSkillEntry]) {
        focusSkills = entries
        if currentFocusIndex >= entries.count { currentFocusIndex = 0 }
        saveFocusSkills()
    }

    // MARK: - Skill idea actions

    func addIdea(name: String, notes: String = "") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        skillIdeas.insert(SkillIdea(name: trimmed, notes: notes), at: 0)
        saveIdeas()
    }

    func deleteIdea(id: UUID) {
        skillIdeas.removeAll { $0.id == id }
        saveIdeas()
    }

    func updateIdea(id: UUID, name: String? = nil, notes: String? = nil) {
        guard let idx = skillIdeas.firstIndex(where: { $0.id == id }) else { return }
        if let n = name  { skillIdeas[idx].name  = n }
        if let n = notes { skillIdeas[idx].notes = n }
        saveIdeas()
    }

    func clear() {
        focusSkills = []; currentFocusIndex = 0; skillIdeas = []
        for key in [focusKey, indexKey, ideasKey, Self.pendingKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: focusKey),
           let skills = try? JSONDecoder().decode([FocusSkillEntry].self, from: data) {
            focusSkills = skills
        }
        currentFocusIndex = UserDefaults.standard.integer(forKey: indexKey)
        if let data = UserDefaults.standard.data(forKey: ideasKey),
           let ideas = try? JSONDecoder().decode([SkillIdea].self, from: data) {
            skillIdeas = ideas
        }
    }

    private func saveFocusSkills() {
        if let data = try? JSONEncoder().encode(focusSkills) {
            UserDefaults.standard.set(data, forKey: focusKey)
        }
    }

    private func saveIdeas() {
        if let data = try? JSONEncoder().encode(skillIdeas) {
            UserDefaults.standard.set(data, forKey: ideasKey)
        }
    }
}
