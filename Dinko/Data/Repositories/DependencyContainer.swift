import SwiftUI

@Observable
final class DependencyContainer {
    let skillRepository: SkillRepository
    let progressCheckerRepository: ProgressCheckerRepository
    let skillRatingRepository: SkillRatingRepository
    let sessionRepository: SessionRepository

    let persistenceError: NSError?

    init(persistence: PersistenceController = .shared) {
        self.persistenceError = persistence.loadError
        self.skillRepository = SkillRepositoryImpl(persistence: persistence)
        self.progressCheckerRepository = ProgressCheckerRepositoryImpl(persistence: persistence)
        self.skillRatingRepository = SkillRatingRepositoryImpl(persistence: persistence)
        self.sessionRepository = SessionRepositoryImpl(persistence: persistence)
    }
}

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
