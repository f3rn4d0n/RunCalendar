import SwiftUI

/// Formulario de edición del perfil del usuario.
struct ProfileEditView: View {
    @State var viewModel: ProfileViewModel
    /// Nombre de Firebase Auth, usado como sugerencia si el perfil aún no tiene nombre.
    let fallbackName: String?

    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var phone = ""
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre", text: $displayName)
                    TextField("Teléfono de contacto", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Cumpleaños") {
                    Toggle("Registrar cumpleaños", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker(
                            "Fecha",
                            selection: $birthday,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                }

                Section("Contacto de emergencia") {
                    TextField("Nombre", text: $emergencyContactName)
                    TextField("Teléfono", text: $emergencyContactPhone)
                        .keyboardType(.phonePad)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { Task { await save() } }
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        let profile = viewModel.profile
        displayName = profile.displayName.isEmpty ? (fallbackName ?? "") : profile.displayName
        phone = profile.phone
        emergencyContactName = profile.emergencyContactName
        emergencyContactPhone = profile.emergencyContactPhone
        if let date = profile.birthday {
            hasBirthday = true
            birthday = date
        }
    }

    private func save() async {
        let updated = UserProfile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            emergencyContactName: emergencyContactName.trimmingCharacters(in: .whitespaces),
            emergencyContactPhone: emergencyContactPhone.trimmingCharacters(in: .whitespaces),
            birthday: hasBirthday ? birthday : nil
        )
        if await viewModel.save(updated) {
            dismiss()
        }
    }
}
