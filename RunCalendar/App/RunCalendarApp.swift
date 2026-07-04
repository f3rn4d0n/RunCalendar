import SwiftUI
import UIKit
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
        Self.configureNavigationAppearance()
        _container = State(initialValue: AppContainer())
    }

    /// Aplica la fuente Permanent Marker a los títulos de navegación de toda la app.
    private static func configureNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if let large = UIFont(name: "PermanentMarker", size: 34) {
            appearance.largeTitleTextAttributes[.font] = large
        }
        if let inline = UIFont(name: "PermanentMarker", size: 18) {
            appearance.titleTextAttributes[.font] = inline
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
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
