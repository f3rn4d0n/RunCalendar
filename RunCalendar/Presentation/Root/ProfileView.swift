import SwiftUI

/// Perfil del usuario y cierre de sesión.
struct ProfileView: View {
    let user: AppUser
    let authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Cuenta") {
                    if let name = user.displayName, !name.isEmpty {
                        LabeledContent("Nombre", value: name)
                    }
                    LabeledContent("Correo", value: user.email ?? "—")
                }

                Section {
                    Button(role: .destructive) {
                        authViewModel.logOut()
                    } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Perfil")
        }
    }
}
