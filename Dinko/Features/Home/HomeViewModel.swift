import SwiftUI

// MARK: - Supporting Types

enum HomeTimeRange: String, CaseIterable {
    case weekly = "Week"
    case monthly = "Month"

    var daysBack: Int {
        switch self {
        case .weekly: 7
        case .monthly: 30
        }
    }
}

struct HomeChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rating: Int
}

struct HomeSkillChartSeries: Identifiable {
    let id: UUID
    let skillName: String
    let color: Color
    let dataPoints: [HomeChartDataPoint]
}

struct HomeRecommendedDrill: Identifiable {
    let id: UUID
    let drillName: String
    let skillName: String
    let durationMinutes: Int
    let priority: String
    let drillDescription: String
    let equipment: String
    let playerCount: Int
    let reason: String
    let targetSubskill: String?
}

struct CompletedSubskill: Identifiable {
    let id: UUID
    let name: String
    let rating: Int
}

struct CompletedSkillItem: Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let rating: Int
    let daysToComplete: Int
    let subskills: [CompletedSubskill]
}

// MARK: - Week Day Model

struct HomeWeekDay: Identifiable {
    let id: Date
    let dayLabel: String    // "M", "T", "W"...
    let dayNumber: Int      // 19, 20, 21...
    let isToday: Bool
    let hasSession: Bool
}

// MARK: - ViewModel

@MainActor
@Observable
final class HomeViewModel {
    private(set) var greetingText = ""
    private(set) var playerName = "Player"
    private(set) var todayDateText = ""

    private(set) var totalActiveSkills = 0
    private(set) var averageRating = 0
    private(set) var mostImprovedSkillName: String?
    private(set) var mostImprovedDelta = 0

    private(set) var chartData: [HomeSkillChartSeries] = []
    private(set) var overallAveragePoints: [HomeChartDataPoint] = []
    private(set) var selectedTimeRange: HomeTimeRange = .weekly
    private(set) var recommendedDrills: [HomeRecommendedDrill] = []

    /// Skills with their latest ratings for the home quick-update list
    private(set) var skillsWithRatings: [(skill: Skill, rating: Int)] = []
    private(set) var completedSkills: [CompletedSkillItem] = []
    private(set) var weeklySkillMovers: [(skill: Skill, delta: Int, currentRating: Int)] = []

    private(set) var streakDays = 0
    private(set) var daysToWeeklyGoal = 0

    private(set) var weekDays: [HomeWeekDay] = []
    private(set) var sessionDatesThisWeek: Set<Date> = []
    private(set) var thisWeekSessionCount = 0
    private(set) var thisWeekTotalMinutes = 0
    private(set) var weeklySessionGoal = 3

    /// Achievement system
    private(set) var achievements: [(achievement: Achievement, isUnlocked: Bool)] = []
    private(set) var newlyUnlockedAchievements: [Achievement] = []
    private(set) var totalSessionsAllTime = 0

    var totalSkillsIncludingCompleted: Int {
        totalActiveSkills + completedSkills.count
    }

    var topDrill: HomeRecommendedDrill? {
        recommendedDrills.first
    }

    // MARK: - Coach Experience Computed Properties

    /// Lowest-rated active skill
    var weakestSkill: (skill: Skill, rating: Int)? {
        skillsWithRatings.min(by: { $0.rating < $1.rating })
    }

    /// Highest-rated active skill
    var strongestSkill: (skill: Skill, rating: Int)? {
        skillsWithRatings.max(by: { $0.rating < $1.rating })
    }

    /// Skill to focus on: biggest weekly decliner, else weakest
    var focusSkill: (skill: Skill, rating: Int)? {
        if let declining = weeklySkillMovers.first(where: { $0.delta < 0 }) {
            return skillsWithRatings.first(where: { $0.skill.id == declining.skill.id })
        }
        return weakestSkill
    }

    /// Average positive delta across weekly movers
    var averageWeeklyImprovement: Double {
        let positives = weeklySkillMovers.filter { $0.delta > 0 }
        guard !positives.isEmpty else { return 0 }
        return Double(positives.map(\.delta).reduce(0, +)) / Double(positives.count)
    }

    /// Mascot state derived from player data
    var mascotState: MascotState {
        if averageRating >= 80 || streakDays >= 7 { return .celebrating }
        if weeklySkillMovers.contains(where: { $0.delta < 0 }) { return .thinking }
        return .idle
    }

    /// Personalized coaching message
    var coachingMessage: String {
        if let declining = weeklySkillMovers.first(where: { $0.delta < 0 }) {
            return "Your \(declining.skill.name) dropped \(abs(declining.delta))% this week. Let's get it back on track!"
        }
        if let weak = weakestSkill, weak.rating < 40 {
            return "\(weak.skill.name) is your biggest opportunity. A few focused sessions can make a real difference."
        }
        if averageRating >= 80 {
            return "You're crushing it! Keep this momentum and push for Weapon tier."
        }
        return "Consistency is key. Log a session today to keep your streak alive!"
    }

    /// CTA label for the coaching card
    var coachingActionLabel: String {
        if weeklySkillMovers.contains(where: { $0.delta < 0 }) {
            return "View Skills"
        }
        if weakestSkill != nil {
            return "View Skills"
        }
        return "View Skills"
    }

    /// Number of skills that improved this week
    var improvedSkillCount: Int {
        weeklySkillMovers.filter { $0.delta > 0 }.count
    }

    private(set) var isLoaded = false
    var errorMessage: String?

    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository
    private let sessionRepository: SessionRepository
    private let journalEntryRepository: JournalEntryRepository

    // Cached data for time range switching
    private var cachedSkills: [Skill] = []
    private var cachedAllSkills: [Skill] = []
    private var cachedRatings: [UUID: [SkillRating]] = [:]

    init(
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        drillRepository: DrillRepository,
        sessionRepository: SessionRepository,
        journalEntryRepository: JournalEntryRepository
    ) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
        self.sessionRepository = sessionRepository
        self.journalEntryRepository = journalEntryRepository
    }

    func loadDashboard() async {
        do {
            updateGreeting()
            resolvePlayerName()

            let allSkills = try await skillRepository.fetchActive()
            cachedAllSkills = allSkills

            // Top-level skills only
            let topLevelSkills = allSkills
                .filter { $0.parentSkillId == nil }
                .sorted { $0.displayOrder < $1.displayOrder }
            cachedSkills = topLevelSkills
            totalActiveSkills = topLevelSkills.count

            // Fetch all ratings and cache them
            var ratingsMap: [UUID: [SkillRating]] = [:]
            for skill in allSkills {
                let ratings = try await skillRatingRepository.fetchForSkill(skill.id)
                ratingsMap[skill.id] = ratings.sorted { $0.date < $1.date }
            }
            cachedRatings = ratingsMap

            computeDerivedData()

            // Load recommended drills
            try await loadRecommendedDrills()

            // Load completed skills
            try await loadCompletedSkills()

            // Compute practice streak
            try await computeStreak()

            // Evaluate achievements
            await evaluateAchievements()

            isLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load dashboard. Please try again."
        }
    }

    func updateTimeRange(_ range: HomeTimeRange) {
        selectedTimeRange = range
        computeDerivedData()
    }

    func saveRating(for skillId: UUID, rating: Int, notes: String?) async -> Bool {
        do {
            // Get old rating before saving
            let oldRating = cachedRatings[skillId]?.last?.rating ?? 0
            let skillName = cachedAllSkills.first(where: { $0.id == skillId })?.name ?? "Skill"

            let newRating = SkillRating(
                id: UUID(),
                skillId: skillId,
                rating: rating,
                date: Date(),
                notes: notes,
                updatedAt: Date()
            )
            try await skillRatingRepository.save(newRating)

            // Update cached ratings
            var existing = cachedRatings[skillId] ?? []
            existing.append(newRating)
            cachedRatings[skillId] = existing

            // Log to timeline
            let delta = rating - oldRating
            let deltaStr = delta >= 0 ? "+\(delta)" : "\(delta)"
            let entry = JournalEntry(
                sessionId: "manual-\(UUID().uuidString)",
                sessionType: nil,
                userNote: "",
                coachInsight: "",
                skillUpdatesSummary: "\(skillName)|\(oldRating)|\(rating)|\(deltaStr)",
                skillUpdatesCount: 1
            )
            try await journalEntryRepository.save(entry)

            // Auto-complete skill at 100%
            if rating >= 100 {
                try await skillRepository.archive(skillId)

                // Also archive child skills
                let children = cachedAllSkills.filter { $0.parentSkillId == skillId }
                for child in children {
                    try await skillRepository.archive(child.id)
                }

                // Refresh everything so the skill moves from active to completed
                await loadDashboard()
            } else {
                computeSkillsWithRatings()
                computeDerivedData()
            }

            return true
        } catch {
            errorMessage = "Failed to save rating."
            return false
        }
    }

    // MARK: - Private Helpers

    private func evaluateAchievements() async {
        // Gather total session count
        let allSessions = (try? await sessionRepository.fetchAll()) ?? []
        totalSessionsAllTime = allSessions.count

        let drillsCompleted = UserDefaults.standard.integer(forKey: "pkkl_total_drills_completed")

        let context = AchievementManager.Context(
            streakDays: streakDays,
            weeklyGoalMet: thisWeekSessionCount >= weeklySessionGoal,
            totalActiveSkills: totalActiveSkills,
            averageRating: averageRating,
            completedSkillCount: completedSkills.count,
            totalSessionsAllTime: allSessions.count,
            weeklySkillMovers: weeklySkillMovers.map { (delta: $0.delta, currentRating: $0.currentRating) },
            skillRatings: skillsWithRatings.map(\.rating),
            totalDrillsCompleted: drillsCompleted
        )

        newlyUnlockedAchievements = AchievementManager.evaluate(context: context)
        achievements = AchievementManager.allAchievements()
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: greetingText = "Good morning"
        case 12..<17: greetingText = "Good afternoon"
        default: greetingText = "Good evening"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        todayDateText = formatter.string(from: Date())
    }

    private func resolvePlayerName() {
        if let firstName = UserDefaults.standard.string(forKey: "pkkl_first_name"),
           !firstName.isEmpty {
            playerName = firstName.capitalized
            return
        }

        if let data = UserDefaults.standard.data(forKey: "pkkl_user_json") {
            struct MinimalUser: Decodable { let email: String? }
            if let user = try? JSONDecoder().decode(MinimalUser.self, from: data),
               let email = user.email {
                let prefix = email.components(separatedBy: "@").first ?? ""
                if !prefix.isEmpty {
                    playerName = prefix
                }
            }
        }
    }

    private func computeDerivedData() {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -selectedTimeRange.daysBack,
            to: Date()
        ) ?? Date()

        computeLatestRatingsAndAverage()
        computeSkillsWithRatings()
        computeChartData(since: cutoff)
        computeWeeklyMovers()
    }

    private func computeSkillsWithRatings() {
        var pairs: [(skill: Skill, rating: Int)] = []
        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }
            if childSkills.isEmpty {
                let latest = cachedRatings[skill.id]?.last?.rating ?? 0
                pairs.append((skill, latest))
            } else {
                var total = 0, count = 0
                for child in childSkills {
                    if let r = cachedRatings[child.id]?.last?.rating {
                        total += r; count += 1
                    }
                }
                // Also consider direct parent ratings
                if let parentRating = cachedRatings[skill.id]?.last?.rating, count == 0 {
                    pairs.append((skill, parentRating))
                } else {
                    let avg = count > 0 ? total / count : 0
                    pairs.append((skill, avg))
                }
            }
        }
        skillsWithRatings = pairs
    }

    private func computeWeeklyMovers() {
        let calendar = Calendar.current
        guard let weekCutoff = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            weeklySkillMovers = []
            return
        }

        var movers: [(skill: Skill, delta: Int, currentRating: Int)] = []

        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }

            if childSkills.isEmpty {
                // Leaf skill
                let ratings = cachedRatings[skill.id] ?? []
                guard let latest = ratings.last else { continue }
                let currentRating = latest.rating

                // Baseline: most recent rating on or before the cutoff
                let baseline = ratings.last(where: { $0.date <= weekCutoff })?.rating ?? ratings.first?.rating
                guard let base = baseline else { continue }

                let delta = currentRating - base
                if delta != 0 {
                    movers.append((skill, delta, currentRating))
                }
            } else {
                // Parent skill: average children's baselines vs current averages
                var currentTotal = 0, currentCount = 0
                var baseTotal = 0, baseCount = 0

                for child in childSkills {
                    let ratings = cachedRatings[child.id] ?? []
                    if let latest = ratings.last {
                        currentTotal += latest.rating
                        currentCount += 1
                    }
                    if let base = ratings.last(where: { $0.date <= weekCutoff })?.rating ?? ratings.first?.rating {
                        baseTotal += base
                        baseCount += 1
                    }
                }

                guard currentCount > 0 && baseCount > 0 else { continue }
                let currentAvg = currentTotal / currentCount
                let baseAvg = baseTotal / baseCount
                let delta = currentAvg - baseAvg

                if delta != 0 {
                    movers.append((skill, delta, currentAvg))
                }
            }
        }

        // Sort by absolute delta descending
        weeklySkillMovers = movers.sorted { abs($0.delta) > abs($1.delta) }
    }

    private func computeLatestRatingsAndAverage() {
        var latestRatings: [Int] = []
        var bestDelta = 0
        var bestSkillName: String?

        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }

            if childSkills.isEmpty {
                // Leaf skill
                if let latest = cachedRatings[skill.id]?.last {
                    latestRatings.append(latest.rating)
                }
                let sorted = cachedRatings[skill.id] ?? []
                if sorted.count >= 2 {
                    let delta = sorted[sorted.count - 1].rating - sorted[sorted.count - 2].rating
                    if delta > bestDelta {
                        bestDelta = delta
                        bestSkillName = skill.name
                    }
                }
            } else {
                // Parent skill: average of children's latest
                var total = 0
                var count = 0
                var currentTotal = 0
                var previousTotal = 0
                var hasHistory = false

                for child in childSkills {
                    if let latest = cachedRatings[child.id]?.last {
                        total += latest.rating
                        count += 1
                    }
                    let childRatings = cachedRatings[child.id] ?? []
                    if childRatings.count >= 2 {
                        currentTotal += childRatings[childRatings.count - 1].rating
                        previousTotal += childRatings[childRatings.count - 2].rating
                        hasHistory = true
                    } else if let first = childRatings.first {
                        currentTotal += first.rating
                        previousTotal += first.rating
                    }
                }
                if count > 0 {
                    latestRatings.append(total / count)
                }
                if hasHistory && !childSkills.isEmpty {
                    let delta = (currentTotal / childSkills.count) - (previousTotal / childSkills.count)
                    if delta > bestDelta {
                        bestDelta = delta
                        bestSkillName = skill.name
                    }
                }
            }
        }

        averageRating = latestRatings.isEmpty ? 0 : latestRatings.reduce(0, +) / latestRatings.count
        mostImprovedDelta = bestDelta
        mostImprovedSkillName = bestDelta > 0 ? bestSkillName : nil
    }

    private func computeChartData(since cutoff: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var series: [HomeSkillChartSeries] = []

        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }

            var dataPoints: [HomeChartDataPoint] = []

            if childSkills.isEmpty {
                // Leaf skill: collect all ratings for this skill
                let allRatings = cachedRatings[skill.id] ?? []

                // Anchor: most recent rating BEFORE the cutoff (so the line has a start)
                if let anchor = allRatings.last(where: { $0.date < cutoff }) {
                    dataPoints.append(HomeChartDataPoint(date: calendar.startOfDay(for: cutoff), rating: anchor.rating))
                }

                // Ratings within the window, deduplicated by day
                let windowRatings = allRatings.filter { $0.date >= cutoff }
                var latestByDay: [Date: SkillRating] = [:]
                for r in windowRatings {
                    let day = calendar.startOfDay(for: r.date)
                    if let existing = latestByDay[day] {
                        if r.date > existing.date {
                            latestByDay[day] = r
                        }
                    } else {
                        latestByDay[day] = r
                    }
                }
                for (day, r) in latestByDay.sorted(by: { $0.key < $1.key }) {
                    dataPoints.append(HomeChartDataPoint(date: day, rating: r.rating))
                }

                // Carry-forward: extend the last known rating to today
                if let lastPoint = dataPoints.last, lastPoint.date < today {
                    dataPoints.append(HomeChartDataPoint(date: today, rating: lastPoint.rating))
                }
            } else {
                // Parent skill: build a synthetic timeline from child AND parent ratings
                // Collect all relevant dates from children and the parent itself
                var dateSet: Set<Date> = []
                for child in childSkills {
                    for r in (cachedRatings[child.id] ?? []) where r.date >= cutoff {
                        dateSet.insert(calendar.startOfDay(for: r.date))
                    }
                }
                // Also include dates from direct parent ratings (AI session updates)
                for r in (cachedRatings[skill.id] ?? []) where r.date >= cutoff {
                    dateSet.insert(calendar.startOfDay(for: r.date))
                }

                // Check if any child/parent has data before cutoff for an anchor
                var hasAnchor = false
                for child in childSkills {
                    if (cachedRatings[child.id] ?? []).contains(where: { $0.date < cutoff }) {
                        hasAnchor = true
                        break
                    }
                }
                if !hasAnchor {
                    hasAnchor = (cachedRatings[skill.id] ?? []).contains(where: { $0.date < cutoff })
                }
                if hasAnchor {
                    dateSet.insert(calendar.startOfDay(for: cutoff))
                }

                // Always include today for carry-forward
                if !dateSet.isEmpty {
                    dateSet.insert(today)
                }

                let sortedDates = dateSet.sorted()

                for date in sortedDates {
                    var total = 0
                    var count = 0
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date

                    for child in childSkills {
                        let childRatings = cachedRatings[child.id] ?? []
                        if let latest = childRatings.last(where: { $0.date < endOfDay }) {
                            total += latest.rating
                            count += 1
                        }
                    }

                    // Also consider direct parent ratings (from AI session updates)
                    let parentRatings = cachedRatings[skill.id] ?? []
                    if let latestParent = parentRatings.last(where: { $0.date < endOfDay }) {
                        // Use parent rating if no child data, or blend it in
                        if count == 0 {
                            total += latestParent.rating
                            count += 1
                        }
                    }

                    if count > 0 {
                        let avg = total / count
                        // Avoid duplicate values at the same rating if the carry-forward
                        // would just repeat the last point at the same value
                        if let last = dataPoints.last, last.date == date {
                            continue
                        }
                        dataPoints.append(HomeChartDataPoint(date: date, rating: avg))
                    }
                }
            }

            guard !dataPoints.isEmpty else { continue }

            let latestRating = dataPoints.last?.rating ?? 0
            let tier = SkillTier(rating: latestRating)
            series.append(HomeSkillChartSeries(
                id: skill.id,
                skillName: skill.name,
                color: tier.color,
                dataPoints: dataPoints
            ))
        }

        chartData = series
        overallAveragePoints = computeOverallAverage(from: series)
    }

    private func computeOverallAverage(from series: [HomeSkillChartSeries]) -> [HomeChartDataPoint] {
        var allDates: Set<Date> = []
        for s in series {
            for p in s.dataPoints {
                allDates.insert(p.date)
            }
        }

        let sortedDates = allDates.sorted()
        var result: [HomeChartDataPoint] = []

        for date in sortedDates {
            var total = 0, count = 0
            for s in series {
                if let point = s.dataPoints.last(where: { $0.date <= date }) {
                    total += point.rating
                    count += 1
                }
            }
            if count > 0 {
                result.append(HomeChartDataPoint(date: date, rating: total / count))
            }
        }

        return result
    }

    private func loadRecommendedDrills() async throws {
        let allDrills = try await drillRepository.fetchAll()
        let pendingDrills = allDrills.filter { $0.status == .pending }

        guard !pendingDrills.isEmpty else {
            recommendedDrills = []
            return
        }

        // Find 3 lowest-rated active skills
        var ratingPairs: [(skill: Skill, rating: Int)] = []
        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }
            if childSkills.isEmpty {
                let latest = cachedRatings[skill.id]?.last?.rating ?? 0
                ratingPairs.append((skill,latest))
            } else {
                var total = 0, count = 0
                for child in childSkills {
                    if let r = cachedRatings[child.id]?.last?.rating {
                        total += r; count += 1
                    }
                }
                let avg = count > 0 ? total / count : 0
                ratingPairs.append((skill,avg))
            }
        }

        let weakestSkillIds = Set(
            ratingPairs
                .sorted { $0.rating < $1.rating }
                .prefix(3)
                .map { $0.skill.id }
        )

        // Also include child skill IDs for parent skills
        var targetSkillIds = weakestSkillIds
        for skillId in weakestSkillIds {
            let children = cachedAllSkills.filter { $0.parentSkillId == skillId }
            for child in children {
                targetSkillIds.insert(child.id)
            }
        }

        // Pick the highest-priority pending drill for each weak skill
        let skillNameMap = Dictionary(
            uniqueKeysWithValues: cachedAllSkills.map { ($0.id, $0.name) }
        )

        var results: [HomeRecommendedDrill] = []
        var usedSkillIds: Set<UUID> = []

        let prioritySorted = pendingDrills.sorted { lhs, rhs in
            let lp = priorityValue(lhs.priority)
            let rp = priorityValue(rhs.priority)
            if lp != rp { return lp < rp }
            return lhs.createdDate < rhs.createdDate
        }

        for drill in prioritySorted {
            guard targetSkillIds.contains(drill.skillId) else { continue }
            let topSkillId: UUID
            if weakestSkillIds.contains(drill.skillId) {
                topSkillId = drill.skillId
            } else if let parent = cachedAllSkills.first(where: { $0.id == drill.skillId })?.parentSkillId,
                      weakestSkillIds.contains(parent) {
                topSkillId = parent
            } else {
                continue
            }

            guard !usedSkillIds.contains(topSkillId) else { continue }
            usedSkillIds.insert(topSkillId)

            results.append(HomeRecommendedDrill(
                id: drill.id,
                drillName: drill.name,
                skillName: skillNameMap[drill.skillId] ?? "Unknown",
                durationMinutes: drill.durationMinutes,
                priority: drill.priority,
                drillDescription: drill.drillDescription,
                equipment: drill.equipment,
                playerCount: drill.playerCount,
                reason: drill.reason,
                targetSubskill: drill.targetSubskill
            ))

            if results.count >= 3 { break }
        }

        recommendedDrills = results
    }

    func deleteCompletedSkill(_ id: UUID) async {
        do {
            let archived = try await skillRepository.fetchArchived()
            let children = archived.filter { $0.parentSkillId == id }
            for child in children {
                try await skillRepository.delete(child.id)
            }
            try await skillRepository.delete(id)
            completedSkills.removeAll { $0.id == id }
        } catch {
            errorMessage = "Failed to delete skill."
        }
    }

    func markDrillDone(_ drillId: UUID) async {
        do {
            try await drillRepository.updateStatus(drillId, status: .completed)
            recommendedDrills.removeAll { $0.id == drillId }
        } catch {
            errorMessage = "Failed to update drill."
        }
    }

    private func loadCompletedSkills() async throws {
        let allCompleted = try await skillRepository.fetchArchived()
        let topLevel = allCompleted.filter { $0.parentSkillId == nil }

        var items: [CompletedSkillItem] = []
        for skill in topLevel {
            let childSkills = allCompleted.filter { $0.parentSkillId == skill.id }
            var subskills: [CompletedSubskill] = []
            let rating: Int
            if childSkills.isEmpty {
                if let latest = try await skillRatingRepository.fetchLatest(skill.id) {
                    rating = latest.rating
                } else {
                    rating = 0
                }
            } else {
                var total = 0, count = 0
                for child in childSkills {
                    let childRating: Int
                    if let latest = try await skillRatingRepository.fetchLatest(child.id) {
                        childRating = latest.rating
                        total += latest.rating
                        count += 1
                    } else {
                        childRating = 0
                    }
                    subskills.append(CompletedSubskill(id: child.id, name: child.name, rating: childRating))
                }
                rating = count > 0 ? total / count : 0
            }
            let days: Int
            if let archived = skill.archivedDate {
                days = max(1, Calendar.current.dateComponents([.day], from: skill.createdDate, to: archived).day ?? 1)
            } else {
                days = max(1, Calendar.current.dateComponents([.day], from: skill.createdDate, to: Date()).day ?? 1)
            }
            items.append(CompletedSkillItem(
                id: skill.id,
                name: skill.name,
                iconName: skill.iconName,
                rating: rating,
                daysToComplete: days,
                subskills: subskills
            ))
        }
        completedSkills = items
    }

    private func computeStreak() async throws {
        let sessions = try await sessionRepository.fetchAll()
        let calendar = Calendar.current

        let savedGoal = UserDefaults.standard.integer(forKey: "pkkl_weekly_goal")
        let weeklyGoal = savedGoal > 0 ? savedGoal : 3
        weeklySessionGoal = weeklyGoal

        var activityDates: Set<Date> = []

        for session in sessions {
            activityDates.insert(calendar.startOfDay(for: session.date))
        }

        for ratings in cachedRatings.values {
            for rating in ratings {
                activityDates.insert(calendar.startOfDay(for: rating.date))
            }
        }

        // Compute week data from sessions
        computeWeekData(sessions: sessions)

        guard !activityDates.isEmpty else {
            streakDays = 0
            daysToWeeklyGoal = weeklyGoal
            return
        }

        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDay = today

        if !activityDates.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                streakDays = 0
                daysToWeeklyGoal = weeklyGoal
                return
            }
            checkDay = yesterday
        }

        while activityDates.contains(checkDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDay) else { break }
            checkDay = prev
        }

        streakDays = streak
        daysToWeeklyGoal = max(0, weeklyGoal - streak)
    }

    private func computeWeekData(sessions: [Session]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find start of the current week (Sunday)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            weekDays = []
            return
        }

        let weekStart = weekInterval.start
        let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

        // Build session dates for this week
        var weekSessionDates: Set<Date> = []
        var weekCount = 0
        var weekMinutes = 0

        for session in sessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            if sessionDay >= weekStart && sessionDay < weekInterval.end {
                weekSessionDates.insert(sessionDay)
                weekCount += 1
                weekMinutes += session.duration
            }
        }

        sessionDatesThisWeek = weekSessionDates
        thisWeekSessionCount = weekCount
        thisWeekTotalMinutes = weekMinutes

        var days: [HomeWeekDay] = []
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: weekStart) else { continue }
            let dayOfMonth = calendar.component(.day, from: date)
            days.append(HomeWeekDay(
                id: date,
                dayLabel: dayLabels[i],
                dayNumber: dayOfMonth,
                isToday: calendar.isDate(date, inSameDayAs: today),
                hasSession: weekSessionDates.contains(calendar.startOfDay(for: date))
            ))
        }

        weekDays = days
    }

    private func priorityValue(_ priority: String) -> Int {
        switch priority {
        case "high": 0
        case "medium": 1
        default: 2
        }
    }
}
