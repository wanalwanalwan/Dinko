import Foundation
import CoreData

/// Handles one-time data migrations for the Brine Redesign.
/// - Migrates SkillRating (0-100) -> ConfidenceEntry (1-10)
/// - Maps SkillCategory -> SkillPillar on existing skills
/// - Seeds canonical skills for new users from onboarding pillar confidences
final class DataMigrationService {

    private static let migrationKey = "brine_redesign_migration_v1"

    static var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// Run all migrations if not already completed.
    static func runIfNeeded(persistence: PersistenceController) async {
        guard !hasMigrated else { return }

        let context = persistence.newBackgroundContext()
        await context.perform {
            do {
                try migratePillarsOnExistingSkills(context: context)
                try migrateRatingsToConfidence(context: context)
                try context.save()
                UserDefaults.standard.set(true, forKey: migrationKey)
            } catch {
                #if DEBUG
                print("DataMigrationService error: \(error)")
                #endif
            }
        }
    }

    /// Set pillar field on existing SkillEntities that don't have one yet.
    private static func migratePillarsOnExistingSkills(context: NSManagedObjectContext) throws {
        let request = SkillEntity.fetchRequest()
        request.predicate = NSPredicate(format: "pillar == nil OR pillar == %@", "")
        let skills = try context.fetch(request)

        for skill in skills {
            let category = SkillCategory(rawValue: skill.category ?? "dinking") ?? .dinking
            skill.pillar = SkillPillar.from(category: category).rawValue
            skill.updatedAt = Date()
        }
    }

    /// Convert existing SkillRating entries (0-100) into ConfidenceEntry records (1-10).
    /// Formula: max(1, min(10, rating / 10))
    private static func migrateRatingsToConfidence(context: NSManagedObjectContext) throws {
        let request = SkillRatingEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillRatingEntity.date, ascending: true)]
        let ratings = try context.fetch(request)

        for rating in ratings {
            guard let skillId = rating.skillId else { continue }

            let confidence = max(1, min(10, Int(rating.rating) / 10))

            let entry = ConfidenceEntryEntity(context: context)
            entry.id = UUID()
            entry.skillId = skillId
            entry.confidence = Int16(confidence)
            entry.source = ConfidenceSource.manual.rawValue
            entry.date = rating.date ?? Date()
            entry.syncStatus = "pending"
        }
    }

    /// Seed canonical skills for a user after onboarding, using their pillar confidences.
    /// Creates Skill entities for all canonical skills and initial ConfidenceEntry records.
    static func seedCanonicalSkills(
        pillarConfidences: [String: Int],
        persistence: PersistenceController
    ) async {
        let context = persistence.newBackgroundContext()
        await context.perform {
            do {
                for (index, canonical) in CanonicalSkill.all.enumerated() {
                    // Check if skill with this canonicalId already exists
                    let existingRequest = SkillEntity.fetchRequest()
                    existingRequest.predicate = NSPredicate(format: "canonicalId == %@", canonical.id)
                    existingRequest.fetchLimit = 1
                    let existing = try context.fetch(existingRequest).first
                    guard existing == nil else { continue }

                    // Create skill entity
                    let skillEntity = SkillEntity(context: context)
                    let skillId = UUID()
                    skillEntity.id = skillId
                    skillEntity.name = canonical.name
                    skillEntity.category = canonical.pillar.defaultCategory.rawValue
                    skillEntity.pillar = canonical.pillar.rawValue
                    skillEntity.canonicalId = canonical.id
                    skillEntity.descriptionText = canonical.description
                    skillEntity.iconName = canonical.iconName
                    skillEntity.status = "active"
                    skillEntity.displayOrder = Int16(index)
                    skillEntity.hierarchyLevel = 0
                    skillEntity.autoCalculateRating = false
                    skillEntity.createdDate = Date()
                    skillEntity.updatedAt = Date()
                    skillEntity.syncStatus = "pending"

                    // Create initial confidence entry from pillar confidence
                    let pillarConfidence = pillarConfidences[canonical.pillar.rawValue] ?? 3
                    let confEntity = ConfidenceEntryEntity(context: context)
                    confEntity.id = UUID()
                    confEntity.skillId = skillId
                    confEntity.confidence = Int16(min(max(pillarConfidence, 1), 10))
                    confEntity.source = ConfidenceSource.onboarding.rawValue
                    confEntity.date = Date()
                    confEntity.syncStatus = "pending"
                }

                try context.save()
            } catch {
                #if DEBUG
                print("DataMigrationService.seedCanonicalSkills error: \(error)")
                #endif
            }
        }
    }
}

// MARK: - SkillPillar helpers for migration

extension SkillPillar {
    /// Default category to use when creating canonical skills (for backward compat).
    var defaultCategory: SkillCategory {
        switch self {
        case .consistency: return .dinking
        case .transition: return .drops
        case .attack: return .offense
        case .movement: return .defense
        case .strategy: return .strategy
        }
    }
}
