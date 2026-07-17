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
        _healthViewModel = State(initialValue: container.makeHealthViewModel(userID: user.id))
    }

    var body: some View {
        TabView {
            Tab("Calendario", systemImage: "calendar") {
                CalendarView(racesViewModel: racesViewModel, trainingViewModel: trainingViewModel,
                             healthViewModel: healthViewModel)
            }
            Tab("Carreras", systemImage: "flag.checkered") {
                RaceListView(viewModel: racesViewModel, trainingViewModel: trainingViewModel,
                             healthViewModel: healthViewModel)
            }
            Tab("Entrenar", systemImage: "figure.run") {
                TrainingListView(viewModel: trainingViewModel, racesViewModel: racesViewModel)
            }
            Tab("Condición", systemImage: "heart.text.square") {
                HealthView(viewModel: healthViewModel, racesViewModel: racesViewModel)
            }
            Tab("Perfil", systemImage: "person.crop.circle") {
                ProfileView(
                    user: user,
                    authViewModel: authViewModel,
                    viewModel: profileViewModel,
                    remindersViewModel: remindersViewModel
                )
            }
        }
        .task { await remindersViewModel.refresh() }
        .onChange(of: racesViewModel.races) { _, _ in
            Task { await remindersViewModel.refresh() }
        }
        .onChange(of: trainingViewModel.sessions) { _, _ in
            Task { await remindersViewModel.refresh() }
        }
        // Los streams se arrancan aquí, en el contenedor que vive toda la sesión.
        // Si se arrancaran en las pestañas, el TabView cancela el .task de la pestaña
        // no visible y se perderían las actualizaciones en vivo.
        .task { await racesViewModel.start() }
        .task { await trainingViewModel.start() }
        .task { await profileViewModel.start() }
        // Observadores de Salud (HKObserverQuery): re-sincronizan solo cuando
        // HealthKit reporta datos nuevos, sin recargar en cada aparición.
        .task { await trainingViewModel.observeHealthUpdates() }
        .task { await healthViewModel.observeUpdates() }
    }
}
