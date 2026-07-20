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
        #if DEBUG
        // No hay target de tests: la lógica no trivial deja su check y corre al arrancar.
        AssessRecompositionUseCase.selfCheck()
        #endif
    }

    /// Aplica la fuente Permanent Marker a la barra de navegación y a la de pestañas.
    private static func configureNavigationAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        if let large = UIFont(name: "PermanentMarker", size: 34) {
            navAppearance.largeTitleTextAttributes[.font] = large
        }
        if let inline = UIFont(name: "PermanentMarker", size: 18) {
            navAppearance.titleTextAttributes[.font] = inline
        }
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        if let tabFont = UIFont(name: "PermanentMarker", size: 10) {
            let tabAppearance = UITabBarAppearance()
            tabAppearance.configureWithDefaultBackground()
            for item in [tabAppearance.stackedLayoutAppearance,
                         tabAppearance.inlineLayoutAppearance,
                         tabAppearance.compactInlineLayoutAppearance] {
                item.normal.titleTextAttributes[.font] = tabFont
                item.selected.titleTextAttributes[.font] = tabFont
            }
            UITabBar.appearance().standardAppearance = tabAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .environment(\.font, .marker(16, relativeTo: .body)) // fuente por defecto de toda la app
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
