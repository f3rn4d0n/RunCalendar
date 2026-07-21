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
    private let healthRepository: HealthRepository
    private let weatherRepository: WeatherRepository
    private let calendarRepository: CalendarRepository
    private let recoveryLogRepository: RecoveryLogRepository
    private let goalRepository: GoalRepository
    private let bodyLogRepository: BodyLogRepository

    init(
        authRepository: AuthRepository = FirebaseAuthRepository(),
        raceRepository: RaceRepository = FirestoreRaceRepository(),
        trainingRepository: TrainingRepository = FirestoreTrainingRepository(),
        profileRepository: ProfileRepository = FirestoreProfileRepository(),
        reminderScheduler: ReminderScheduler = LocalNotificationService(),
        healthRepository: HealthRepository = HealthKitService(),
        // Open-Meteo hoy; cambiar por WeatherKitService al publicar (mismo protocolo).
        weatherRepository: WeatherRepository = OpenMeteoService(),
        calendarRepository: CalendarRepository = EventKitService(),
        recoveryLogRepository: RecoveryLogRepository = FirestoreRecoveryLogRepository(),
        goalRepository: GoalRepository = FirestoreGoalRepository(),
        bodyLogRepository: BodyLogRepository = FirestoreBodyLogRepository()
    ) {
        self.authRepository = authRepository
        self.raceRepository = raceRepository
        self.trainingRepository = trainingRepository
        self.profileRepository = profileRepository
        self.reminderScheduler = reminderScheduler
        self.healthRepository = healthRepository
        self.weatherRepository = weatherRepository
        self.calendarRepository = calendarRepository
        self.recoveryLogRepository = recoveryLogRepository
        self.goalRepository = goalRepository
        self.bodyLogRepository = bodyLogRepository
    }

    // MARK: - ViewModels

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(
            observeAuthState: ObserveAuthStateUseCase(repository: authRepository),
            signIn: SignInWithEmailUseCase(repository: authRepository),
            signUp: SignUpUseCase(repository: authRepository),
            signInWithApple: SignInWithAppleUseCase(repository: authRepository),
            signInWithGoogle: SignInWithGoogleUseCase(repository: authRepository),
            signOut: SignOutUseCase(repository: authRepository)
        )
    }

    func makeRacesViewModel(userID: String) -> RacesViewModel {
        RacesViewModel(
            userID: userID,
            observeRaces: ObserveRacesUseCase(repository: raceRepository),
            addRace: AddRaceUseCase(repository: raceRepository),
            updateRace: UpdateRaceUseCase(repository: raceRepository),
            deleteRace: DeleteRaceUseCase(repository: raceRepository),
            fetchWeather: FetchRaceWeatherUseCase(repository: weatherRepository),
            addToCalendar: AddToCalendarUseCase(repository: calendarRepository)
        )
    }

    func makeTrainingViewModel(userID: String) -> TrainingViewModel {
        TrainingViewModel(
            userID: userID,
            observeTrainings: ObserveTrainingsUseCase(repository: trainingRepository),
            addTraining: AddTrainingUseCase(repository: trainingRepository),
            updateTraining: UpdateTrainingUseCase(repository: trainingRepository),
            deleteTraining: DeleteTrainingUseCase(repository: trainingRepository),
            fetchRecentWorkouts: FetchRecentWorkoutsUseCase(repository: healthRepository),
            fetchWorkoutRoute: FetchWorkoutRouteUseCase(repository: healthRepository),
            fetchWeather: FetchRaceWeatherUseCase(repository: weatherRepository)
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

    func makeGoalsViewModel(
        userID: String,
        racesViewModel: RacesViewModel,
        trainingViewModel: TrainingViewModel
    ) -> GoalsViewModel {
        GoalsViewModel(
            userID: userID,
            observeGoals: ObserveGoalsUseCase(repository: goalRepository),
            addGoal: AddGoalUseCase(repository: goalRepository),
            updateGoal: UpdateGoalUseCase(repository: goalRepository),
            deleteGoal: DeleteGoalUseCase(repository: goalRepository),
            assessProgress: AssessGoalProgressUseCase(),
            assessConfidence: AssessGoalConfidenceUseCase(),
            assessPace: AssessGoalPaceUseCase(),
            recommendGoal: RecommendGoalUseCase(),
            fetchAthleteMetrics: FetchAthleteMetricsUseCase(repository: healthRepository),
            saveMeasure: SaveBodyMeasureUseCase(repository: healthRepository),
            fetchMeasureHistory: FetchBodyMeasureHistoryUseCase(repository: healthRepository),
            saveBodyLog: SaveBodyLogUseCase(repository: bodyLogRepository),
            fetchBodyLogs: FetchBodyLogsUseCase(repository: bodyLogRepository),
            assessRecomposition: AssessRecompositionUseCase(),
            generatePlan: GeneratePlanUseCase(),
            inferPrimary: InferPrimaryGoalUseCase(),
            racesViewModel: racesViewModel,
            trainingViewModel: trainingViewModel
        )
    }

    func makeHealthViewModel(userID: String, trainingViewModel: TrainingViewModel) -> HealthViewModel {
        HealthViewModel(
            userID: userID,
            fetchSummary: FetchFitnessSummaryUseCase(repository: healthRepository),
            assessReadiness: AssessReadinessUseCase(),
            fetchRecovery: FetchRecoveryUseCase(repository: healthRepository),
            assessRecovery: AssessRecoveryUseCase(),
            fetchRecoveryTrend: FetchRecoveryTrendUseCase(repository: healthRepository),
            fetchWorkload: FetchWorkloadUseCase(repository: healthRepository),
            assessWorkload: AssessWorkloadUseCase(),
            fetchFitnessTrend: FetchFitnessTrendUseCase(repository: healthRepository),
            saveCheckIn: SaveRecoveryCheckInUseCase(repository: recoveryLogRepository),
            fetchCheckIns: FetchRecoveryCheckInsUseCase(repository: recoveryLogRepository),
            computeTrainingLoad: ComputeTrainingLoadUseCase(),
            trainingViewModel: trainingViewModel
        )
    }
}
