import Foundation

/// Composition root. Único lugar que conoce las implementaciones concretas (capa Data)
/// y las inyecta hacia los casos de uso y, a través de las factorías, hacia los ViewModels.
/// Cumple Dependency Inversion: la UI solo recibe casos de uso, nunca repositorios concretos.
@MainActor
final class AppContainer {

    // Repositorios (implementaciones de la capa Data, ocultas tras protocolos)
    private let authRepository: AuthRepository
    private let raceRepository: RaceRepository
    private let trainingRepository: TrainingRepository
    private let profileRepository: ProfileRepository
    private let reminderScheduler: ReminderScheduler

    init(
        authRepository: AuthRepository = FirebaseAuthRepository(),
        raceRepository: RaceRepository = FirestoreRaceRepository(),
        trainingRepository: TrainingRepository = FirestoreTrainingRepository(),
        profileRepository: ProfileRepository = FirestoreProfileRepository(),
        reminderScheduler: ReminderScheduler = LocalNotificationService()
    ) {
        self.authRepository = authRepository
        self.raceRepository = raceRepository
        self.trainingRepository = trainingRepository
        self.profileRepository = profileRepository
        self.reminderScheduler = reminderScheduler
    }

    // MARK: - ViewModels

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            observeAuthState: ObserveAuthStateUseCase(repository: authRepository),
            signIn: SignInWithEmailUseCase(repository: authRepository),
            signUp: SignUpUseCase(repository: authRepository),
            signInWithApple: SignInWithAppleUseCase(repository: authRepository),
            signOut: SignOutUseCase(repository: authRepository)
        )
    }

    func makeRacesViewModel(userID: String) -> RacesViewModel {
        RacesViewModel(
            userID: userID,
            observeRaces: ObserveRacesUseCase(repository: raceRepository),
            addRace: AddRaceUseCase(repository: raceRepository),
            updateRace: UpdateRaceUseCase(repository: raceRepository),
            deleteRace: DeleteRaceUseCase(repository: raceRepository)
        )
    }

    func makeTrainingViewModel(userID: String) -> TrainingViewModel {
        TrainingViewModel(
            userID: userID,
            observeTrainings: ObserveTrainingsUseCase(repository: trainingRepository),
            addTraining: AddTrainingUseCase(repository: trainingRepository),
            updateTraining: UpdateTrainingUseCase(repository: trainingRepository),
            deleteTraining: DeleteTrainingUseCase(repository: trainingRepository)
        )
    }

    func makeProfileViewModel(userID: String) -> ProfileViewModel {
        ProfileViewModel(
            userID: userID,
            observeProfile: ObserveProfileUseCase(repository: profileRepository),
            saveProfile: SaveProfileUseCase(repository: profileRepository)
        )
    }

    func makeRemindersViewModel(
        racesViewModel: RacesViewModel,
        trainingViewModel: TrainingViewModel
    ) -> RemindersViewModel {
        RemindersViewModel(
            scheduler: reminderScheduler,
            racesViewModel: racesViewModel,
            trainingViewModel: trainingViewModel
        )
    }
}
