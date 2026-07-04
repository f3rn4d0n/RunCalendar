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
    @State private var birthDate: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre", text: $displayName)
                    TextField("Teléfono de contacto", text: $phone)
                        .keyboardType(.phonePad)
                }

                birthDateSection

                Section("Contacto de emergencia") {
                    TextField("Nombre", text: $emergencyContactName)
                    TextField("Teléfono", text: $emergencyContactPhone)
                        .keyboardType(.phonePad)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.mFootnote) }
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

    /// Sección de fecha de nacimiento, opcional y sin switch:
    /// si no hay fecha, se ofrece agregarla; si la hay, se puede quitar.
    @ViewBuilder
    private var birthDateSection: some View {
        Section("Fecha de nacimiento") {
            if let date = birthDate {
                DatePicker(
                    "Fecha",
                    selection: Binding(get: { date }, set: { birthDate = $0 }),
                    in: ...Date(),
                    displayedComponents: .date
                )
                Button("Quitar fecha de nacimiento", role: .destructive) {
                    birthDate = nil
                }
            } else {
                Button("Agregar fecha de nacimiento") {
                    birthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
                }
            }
        }
    }

    private func populate() {
        let profile = viewModel.profile
        displayName = profile.displayName.isEmpty ? (fallbackName ?? "") : profile.displayName
        phone = profile.phone
        emergencyContactName = profile.emergencyContactName
        emergencyContactPhone = profile.emergencyContactPhone
        birthDate = profile.birthday
    }

    private func save() async {
        let updated = UserProfile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            emergencyContactName: emergencyContactName.trimmingCharacters(in: .whitespaces),
            emergencyContactPhone: emergencyContactPhone.trimmingCharacters(in: .whitespaces),
            birthday: birthDate
        )
        if await viewModel.save(updated) {
            dismiss()
        }
    }
}
