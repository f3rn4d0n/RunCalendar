import SwiftUI

/// Perfil del usuario: datos personales, contacto de emergencia, cuenta y cierre de sesión.
struct ProfileView: View {
    let user: AppUser
    let authViewModel: AuthViewModel
    @State var viewModel: ProfileViewModel
    @State var remindersViewModel: RemindersViewModel

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
                        LabeledContent("Fecha de nacimiento", value: birthday.mediumString())
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

                Section {
                    Toggle("Recordatorios de eventos", isOn: Binding(
                        get: { remindersViewModel.isEnabled },
                        set: { newValue in Task { await remindersViewModel.setEnabled(newValue) } }
                    ))
                    if remindersViewModel.permissionDenied {
                        Text("Activa las notificaciones de RunCalendar en Ajustes para recibir recordatorios.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Recordatorios")
                } footer: {
                    Text("Te avisamos 7 días antes, la víspera y el día del evento, y de la entrega de kit.")
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
