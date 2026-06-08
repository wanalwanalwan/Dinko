import CoreData
import Foundation

final class ProgramRepositoryImpl: ProgramRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Program CRUD

    func fetchAll() async throws -> [Program] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ProgramEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ProgramEntity.createdDate, ascending: false)]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    func fetchActive() async throws -> Program? {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ProgramEntity.fetchRequest()
            request.predicate = NSPredicate(format: "status == %@", ProgramStatus.active.rawValue)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ProgramEntity.createdDate, ascending: false)]
            request.fetchLimit = 1
            return try context.fetch(request).first?.toDomain()
        }
    }

    func save(_ program: Program) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgramEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", program.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? ProgramEntity(context: context)
            entity.update(from: program)
            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgramEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }

    func updateStatus(_ id: UUID, status: ProgramStatus) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgramEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.status = status.rawValue
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    // MARK: - Sessions

    func fetchSessions(for programId: UUID) async throws -> [ProgramSession] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ProgramSessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "programId == %@", programId as CVarArg)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ProgramSessionEntity.weekNumber, ascending: true),
                NSSortDescriptor(keyPath: \ProgramSessionEntity.sessionNumber, ascending: true)
            ]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    func completeSession(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            // Mark session as completed
            let sessionRequest = ProgramSessionEntity.fetchRequest()
            sessionRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            sessionRequest.fetchLimit = 1
            guard let sessionEntity = try context.fetch(sessionRequest).first else { return }

            sessionEntity.status = ProgramSessionStatus.completed.rawValue
            sessionEntity.completedDate = Date()
            sessionEntity.updatedAt = Date()

            let programId = sessionEntity.programId
            let completedWeek = sessionEntity.weekNumber
            let completedSessionNum = sessionEntity.sessionNumber

            // Fetch the program
            let progRequest = ProgramEntity.fetchRequest()
            progRequest.predicate = NSPredicate(format: "id == %@", programId! as CVarArg)
            progRequest.fetchLimit = 1
            guard let programEntity = try context.fetch(progRequest).first else {
                try context.save()
                return
            }

            let totalWeeks = programEntity.totalWeeks
            let sessionsPerWeek = programEntity.sessionsPerWeek

            // Find and unlock next session
            if completedSessionNum < sessionsPerWeek {
                // More sessions in current week
                let nextRequest = ProgramSessionEntity.fetchRequest()
                nextRequest.predicate = NSPredicate(
                    format: "programId == %@ AND weekNumber == %d AND sessionNumber == %d",
                    programId! as CVarArg, completedWeek, completedSessionNum + 1
                )
                nextRequest.fetchLimit = 1
                if let nextSession = try context.fetch(nextRequest).first {
                    nextSession.status = ProgramSessionStatus.available.rawValue
                    nextSession.updatedAt = Date()
                }
                programEntity.currentSession = completedSessionNum + 1
                programEntity.updatedAt = Date()
            } else if completedWeek < totalWeeks {
                // Last session in week, advance to next week
                let nextRequest = ProgramSessionEntity.fetchRequest()
                nextRequest.predicate = NSPredicate(
                    format: "programId == %@ AND weekNumber == %d AND sessionNumber == 1",
                    programId! as CVarArg, completedWeek + 1
                )
                nextRequest.fetchLimit = 1
                if let nextSession = try context.fetch(nextRequest).first {
                    nextSession.status = ProgramSessionStatus.available.rawValue
                    nextSession.updatedAt = Date()
                }
                programEntity.currentWeek = completedWeek + 1
                programEntity.currentSession = 1
                programEntity.updatedAt = Date()
            } else {
                // Last session of last week — program complete
                programEntity.status = ProgramStatus.completed.rawValue
                programEntity.updatedAt = Date()
            }

            try context.save()
        }
    }

    // MARK: - Drills

    func fetchDrills(for sessionId: UUID) async throws -> [ProgramDrill] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ProgramDrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "programSessionId == %@", sessionId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ProgramDrillEntity.displayOrder, ascending: true)]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    func completeDrill(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgramDrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.status = DrillStatus.completed.rawValue
                entity.completedReps = entity.targetReps
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    func updateDrillStatus(_ id: UUID, status: DrillStatus) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgramDrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.status = status.rawValue
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    func incrementDrillReps(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgramDrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.completedReps += 1
                if entity.completedReps >= entity.targetReps {
                    entity.status = DrillStatus.completed.rawValue
                }
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    // MARK: - Atomic Full Program Save

    func saveFullProgram(
        _ program: Program,
        sessions: [ProgramSession],
        drills: [UUID: [ProgramDrill]]
    ) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            // Save program
            let programEntity = ProgramEntity(context: context)
            programEntity.update(from: program)

            // Save sessions and their drills
            for session in sessions {
                let sessionEntity = ProgramSessionEntity(context: context)
                sessionEntity.update(from: session)
                sessionEntity.program = programEntity

                if let sessionDrills = drills[session.id] {
                    for drill in sessionDrills {
                        let drillEntity = ProgramDrillEntity(context: context)
                        drillEntity.update(from: drill)
                        drillEntity.session = sessionEntity
                    }
                }
            }

            try context.save()
        }
    }
}
