import SwiftUI

/// Captura lo único que el generador de plan necesita del usuario: cuántos días por semana puede
/// entrenar y (opcional) cuáles. Al cambiar, el plan y la "misión de hoy" se recalculan solos.
struct PlanConfigSheet: View {
    @Bindable var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Días por semana: \(viewModel.planConfig.daysPerWeek)",
                            value: $viewModel.planConfig.daysPerWeek, in: 2...6)
                } footer: {
                    Text("Cuántas veces puedes correr en la semana. El plan reparte tirada larga, "
                        + "tempo y series según esto.")
                }

                Section {
                    weekdayPicker
                } header: {
                    Text("Días preferidos (opcional)")
                } footer: {
                    Text("Si no eliges, el plan usa un reparto espaciado por defecto.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Tu plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.shortWeekdaySymbols   // 1=Dom … 7=Sáb
        return HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let on = viewModel.planConfig.preferredWeekdays.contains(weekday)
                Button(symbols[weekday - 1]) { toggle(weekday) }
                    .buttonStyle(.plain)
                    .font(.mCaption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(on ? Neon.accent.opacity(0.2) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(on ? AnyShapeStyle(Neon.accent) : AnyShapeStyle(.secondary))
            }
        }
    }

    private func toggle(_ weekday: Int) {
        if let i = viewModel.planConfig.preferredWeekdays.firstIndex(of: weekday) {
            viewModel.planConfig.preferredWeekdays.remove(at: i)
        } else {
            viewModel.planConfig.preferredWeekdays.append(weekday)
        }
    }
}
