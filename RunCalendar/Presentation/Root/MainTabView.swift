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

    init(container: AppContainer, user: AppUser, authViewModel: AuthViewModel) {
        self.container = container
        self.user = user
        self.authViewModel = authViewModel
        _racesViewModel = State(initialValue: container.makeRacesViewModel(userID: user.id))
        _trainingViewModel = State(initialValue: container.makeTrainingViewModel(userID: user.id))
        _profileViewModel = State(initialValue: container.makeProfileViewModel(userID: user.id))
    }

    var body: some View {
        TabView {
            Tab("Calendario", systemImage: "calendar") {
                CalendarView(racesViewModel: racesViewModel, trainingViewModel: trainingViewModel)
            }
            Tab("Carreras", systemImage: "flag.checkered") {
                RaceListView(viewModel: racesViewModel)
            }
            Tab("Entrenar", systemImage: "figure.run") {
                TrainingListView(viewModel: trainingViewModel)
            }
            Tab("Perfil", systemImage: "person.crop.circle") {
                ProfileView(user: user, authViewModel: authViewModel, viewModel: profileViewModel)
            }
        }
        // Los streams se arrancan aquí, en el contenedor que vive toda la sesión.
        // Si se arrancaran en las pestañas, el TabView cancela el .task de la pestaña
        // no visible y se perderían las actualizaciones en vivo.
        .task { await racesViewModel.start() }
        .task { await trainingViewModel.start() }
        .task { await profileViewModel.start() }
    }
}
