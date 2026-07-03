import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct RunCalendarApp: App {

    /// Composition root único para toda la app.
    @State private var container: AppContainer

    init() {
        // Firebase DEBE configurarse antes de crear el AppContainer, porque éste
        // instancia repositorios que acceden a Auth.auth() / Firestore.firestore().
        FirebaseApp.configure()
        let projectID = FirebaseApp.app()?.options.projectID ?? "nil"
        Log.app.info("Firebase configurado, projectID=\(projectID, privacy: .public)")
        _container = State(initialValue: AppContainer())
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
