import SwiftUI

/// Ajustes de recordatorios: activar/desactivar y configurar qué avisos recibir y a qué hora.
struct RemindersSettingsView: View {
    let viewModel: RemindersViewModel
    @State private var prefs: ReminderPreferences

    init(viewModel: RemindersViewModel) {
        self.viewModel = viewModel
        _prefs = State(initialValue: viewModel.preferences)
    }

    private var leadDaysLabel: String {
        prefs.leadDays > 0 ? "Aviso anticipado: \(prefs.leadDays) días" : "Aviso anticipado: apagado"
    }

    var body: some View {
        Form {
            Section {
                Toggle("Recordatorios de eventos", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { newValue in Task { await viewModel.setEnabled(newValue) } }
                ))
                if viewModel.permissionDenied {
                    Text("Activa las notificaciones de RunCalendar en Ajustes para recibir recordatorios.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.isEnabled {
                Section("Carreras") {
                    Stepper(leadDaysLabel, value: $prefs.leadDays, in: 0...60)
                    Toggle("La víspera", isOn: $prefs.dayBefore)
                    Toggle("El día del evento", isOn: $prefs.dayOf)
                    Toggle("Entrega de kit", isOn: $prefs.kit)
                }

                Section("Entrenamientos") {
                    Toggle("Avisar entrenamientos", isOn: $prefs.trainings)
                }

                Section {
                    Picker("Hora del aviso", selection: $prefs.reminderHour) {
                        ForEach(5...22, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                } footer: {
                    Text("Hora de los avisos por fecha. Los entrenamientos avisan a la hora de la sesión.")
                }
            }
        }
        .navigationTitle("Recordatorios")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: prefs) { _, newValue in
            Task { await viewModel.updatePreferences(newValue) }
        }
    }
}
