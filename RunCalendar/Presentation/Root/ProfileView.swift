import SwiftUI

/// Perfil del usuario: datos personales, contacto de emergencia, cuenta y cierre de sesión.
struct ProfileView: View {
    let user: AppUser
    let authViewModel: AuthViewModel
    @State var viewModel: ProfileViewModel

    @State private var isEditing = false

    private var profile: UserProfile { viewModel.profile }

    /// Nombre a mostrar: el del perfil, o el de Auth como respaldo.
    private var displayName: String {
        if !profile.displayName.isEmpty { return profile.displayName }
        return user.displayName ?? "—"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Datos personales") {
                    LabeledContent("Nombre", value: displayName)
                    if !profile.phone.isEmpty {
                        LabeledContent("Teléfono", value: profile.phone)
                    }
                    if let birthday = profile.birthday {
                        LabeledContent("Cumpleaños", value: birthday.mediumString())
                    }
                    if let age = profile.age {
                        LabeledContent("Edad", value: "\(age) años")
                    }
                }

                if !profile.emergencyContactName.isEmpty || !profile.emergencyContactPhone.isEmpty {
                    Section("Contacto de emergencia") {
                        if !profile.emergencyContactName.isEmpty {
                            LabeledContent("Nombre", value: profile.emergencyContactName)
                        }
                        if !profile.emergencyContactPhone.isEmpty {
                            LabeledContent("Teléfono", value: profile.emergencyContactPhone)
                        }
                    }
                }

                Section("Cuenta") {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Editar") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                ProfileEditView(viewModel: viewModel, fallbackName: user.displayName)
            }
        }
    }
}
