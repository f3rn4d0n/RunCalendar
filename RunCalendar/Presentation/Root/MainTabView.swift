import SwiftUI

/// Navegación principal una vez autenticado. Crea los ViewModels (vía el contenedor de DI)
/// y los comparte entre las pestañas que los necesitan.
struct MainTabView: View {
    let container: AppContainer
    let user: AppUser
    let authViewModel: AuthViewModel

    @State private var racesViewModel: RacesViewModel
    @State private var trainingViewModel: TrainingViewModel
    @State private var profileViewModel: ProfileViewModel
    @State private var remindersViewModel: RemindersViewModel
    @State private var healthViewModel: HealthViewModel
    @State private var goalsViewModel: GoalsViewModel

    init(container: AppContainer, user: AppUser, authViewModel: AuthViewModel) {
        self.container = container
        self.user = user
        self.authViewModel = authViewModel
        let races = container.makeRacesViewModel(userID: user.id)
        let trainings = container.makeTrainingViewModel(userID: user.id)
        _racesViewModel = State(initialValue: races)
        _trainingViewModel = State(initialValue: trainings)
        _profileViewModel = State(initialValue: container.makeProfileViewModel(userID: user.id))
        _remindersViewModel = State(initialValue: container.makeRemindersViewModel(
            racesViewModel: races,
            trainingViewModel: trainings
        ))
        _healthViewModel = State(initialValue: container.makeHealthViewModel(
            userID: user.id, trainingViewModel: trainings
        ))
        _goalsViewModel = State(initialValue: container.makeGoalsViewModel(
            userID: user.id, racesViewModel: races, trainingViewModel: trainings
        ))
    }

    var body: some View {
        TabView {
            Tab("Hoy", systemImage: "sun.max") {
                HoyView(
                    racesViewModel: racesViewModel,
                    trainingViewModel: trainingViewModel,
                    healthViewModel: healthViewModel,
                    goalsViewModel: goalsViewModel,
                    user: user,
                    authViewModel: authViewModel,
                    profileViewModel: profileViewModel,
                    remindersViewModel: remindersViewModel
                )
            }
            Tab("Entrenar", systemImage: "figure.run") {
                TrainingListView(viewModel: trainingViewModel, racesViewModel: racesViewModel)
            }
            Tab("Objetivos", systemImage: "target") {
                GoalsView(viewModel: goalsViewModel)
            }
            Tab("Progreso", systemImage: "chart.line.uptrend.xyaxis") {
                HealthView(viewModel: healthViewModel, racesViewModel: racesViewModel,
                           goalsViewModel: goalsViewModel)
            }
        }
        .task { await remindersViewModel.refresh() }
        .onChange(of: racesViewModel.races) { _, _ in
            Task { await remindersViewModel.refresh() }
        }
        .onChange(of: trainingViewModel.sessions) { _, _ in
            Task { await remindersViewModel.refresh() }
            // La carga de las sesiones alimenta recuperación/ACWR: recalcula si ya hay datos.
            Task { await healthViewModel.reloadIfLoaded() }
        }
        // Los streams se arrancan aquí, en el contenedor que vive toda la sesión.
        // Si se arrancaran en las pestañas, el TabView cancela el .task de la pestaña
        // no visible y se perderían las actualizaciones en vivo.
        .task { await racesViewModel.start() }
        .task { await trainingViewModel.start() }
        .task { await profileViewModel.start() }
        .task { await goalsViewModel.start() }
        // Carga inicial de Condición aquí (no solo en la tab Progreso): la card de
        // recuperación de "Hoy" la necesita aunque nunca abras Progreso.
        .task { await healthViewModel.onAppear() }
        // Observadores de Salud (HKObserverQuery): re-sincronizan solo cuando
        // HealthKit reporta datos nuevos, sin recargar en cada aparición.
        .task { await trainingViewModel.observeHealthUpdates() }
        .task { await healthViewModel.observeUpdates() }
    }
}
