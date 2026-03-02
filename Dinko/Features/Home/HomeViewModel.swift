import SwiftUI
import Charts

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

struct HomeSkillMover: Identifiable {
    let id: UUID
    let skillName: String
    let iconName: String
    let currentRating: Int
    let delta: Int
    let tier: SkillTier
}

struct HomeRecommendedDrill: Identifiable {
    let id: UUID
    let drillName: String
    let skillName: String
    let durationMinutes: Int
    let priority: String
}

struct CompletedSkillItem: Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let rating: Int
    let completedDate: Date?
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
    private(set) var selectedTimeRange: HomeTimeRange = .weekly
    private(set) var topMovers: [HomeSkillMover] = []
    private(set) var recommendedDrills: [HomeRecommendedDrill] = []
    private(set) var completedSkills: [CompletedSkillItem] = []

    private(set) var isLoaded = false
    var errorMessage: String?

    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository

    // Cached data for time range switching
    private var cachedSkills: [Skill] = []
    private var cachedAllSkills: [Skill] = []
    private var cachedRatings: [UUID: [SkillRating]] = [:]

    init(
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        drillRepository: DrillRepository
    ) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
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

    // MARK: - Private Helpers

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
        if let data = UserDefaults.standard.data(forKey: "dinkit_user_json") {
            struct MinimalUser: Decodable { let email: String? }
            if let user = try? JSONDecoder().decode(MinimalUser.self, from: data),
               let email = user.email {
                let prefix = email.components(separatedBy: "@").first ?? ""
                if !prefix.isEmpty {
                    playerName = prefix.capitalized
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
        computeChartData(since: cutoff)
        computeTopMovers(since: cutoff)
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
        var series: [HomeSkillChartSeries] = []

        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }

            var dataPoints: [HomeChartDataPoint] = []

            if childSkills.isEmpty {
                // Leaf skill: deduplicate by day, keep only latest per day
                let ratings = (cachedRatings[skill.id] ?? [])
                    .filter { $0.date >= cutoff }
                var latestByDay: [Date: SkillRating] = [:]
                for r in ratings {
                    let day = Calendar.current.startOfDay(for: r.date)
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
            } else {
                // Parent skill: build a synthetic timeline from child ratings
                // Collect all unique dates from children in range
                var dateSet: Set<Date> = []
                for child in childSkills {
                    for r in (cachedRatings[child.id] ?? []) where r.date >= cutoff {
                        dateSet.insert(Calendar.current.startOfDay(for: r.date))
                    }
                }
                let sortedDates = dateSet.sorted()

                for date in sortedDates {
                    var total = 0
                    var count = 0
                    for child in childSkills {
                        // Find the latest rating on or before this date
                        let childRatings = cachedRatings[child.id] ?? []
                        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                        if let latest = childRatings.last(where: { $0.date < endOfDay }) {
                            total += latest.rating
                            count += 1
                        }
                    }
                    if count > 0 {
                        dataPoints.append(HomeChartDataPoint(date: date, rating: total / count))
                    }
                }
            }

            guard !dataPoints.isEmpty else { continue }

            // Single point looks like a lonely dot — add a prior-day point
            // at the same rating so it renders as a short flat line
            if dataPoints.count == 1, let only = dataPoints.first,
               let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: only.date) {
                dataPoints.insert(HomeChartDataPoint(date: dayBefore, rating: only.rating), at: 0)
            }

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
    }

    private func computeTopMovers(since cutoff: Date) {
        var movers: [HomeSkillMover] = []

        for skill in cachedSkills {
            let childSkills = cachedAllSkills.filter { $0.parentSkillId == skill.id }

            if childSkills.isEmpty {
                let ratings = (cachedRatings[skill.id] ?? [])
                    .filter { $0.date >= cutoff }
                    .sorted { $0.date < $1.date }

                guard ratings.count >= 2 else { continue }
                let delta = ratings.last!.rating - ratings.first!.rating
                guard delta > 0 else { continue }

                let currentRating = ratings.last!.rating
                movers.append(HomeSkillMover(
                    id: skill.id,
                    skillName: skill.name,
                    iconName: skill.iconName,
                    currentRating: currentRating,
                    delta: delta,
                    tier: SkillTier(rating: currentRating)
                ))
            } else {
                // Parent: compare average at start vs end of range
                var startTotal = 0, endTotal = 0, count = 0
                for child in childSkills {
                    let childRatings = (cachedRatings[child.id] ?? [])
                        .filter { $0.date >= cutoff }
                        .sorted { $0.date < $1.date }
                    guard childRatings.count >= 2 else { continue }
                    startTotal += childRatings.first!.rating
                    endTotal += childRatings.last!.rating
                    count += 1
                }
                guard count > 0 else { continue }
                let delta = (endTotal / count) - (startTotal / count)
                guard delta > 0 else { continue }

                let currentRating = endTotal / count
                movers.append(HomeSkillMover(
                    id: skill.id,
                    skillName: skill.name,
                    iconName: skill.iconName,
                    currentRating: currentRating,
                    delta: delta,
                    tier: SkillTier(rating: currentRating)
                ))
            }
        }

        topMovers = movers
            .sorted { $0.delta > $1.delta }
            .prefix(3)
            .map { $0 }
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
            // Find the top-level skill this drill belongs to
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
                priority: drill.priority
            ))

            if results.count >= 3 { break }
        }

        recommendedDrills = results
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
                    if let latest = try await skillRatingRepository.fetchLatest(child.id) {
                        total += latest.rating
                        count += 1
                    }
                }
                rating = count > 0 ? total / count : 0
            }
            items.append(CompletedSkillItem(
                id: skill.id,
                name: skill.name,
                iconName: skill.iconName,
                rating: rating,
                completedDate: skill.archivedDate
            ))
        }
        completedSkills = items
    }

    private func priorityValue(_ priority: String) -> Int {
        switch priority {
        case "high": 0
        case "medium": 1
        default: 2
        }
    }
}
