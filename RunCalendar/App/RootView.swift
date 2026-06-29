import SwiftUI

/// Decide qué mostrar según el estado de la sesión: carga, login o app principal.
struct RootView: View {
    let container: AppContainer
    @State private var authViewModel: AuthViewModel

    init(container: AppContainer) {
        self.container = container
        _authViewModel = State(initialValue: container.makeAuthViewModel())
    }

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView("Cargando…")
            case .signedOut:
                LoginView(viewModel: authViewModel)
            case .signedIn(let user):
                MainTabView(container: container, user: user, authViewModel: authViewModel)
            }
        }
        .task { await authViewModel.start() }
    }
}
