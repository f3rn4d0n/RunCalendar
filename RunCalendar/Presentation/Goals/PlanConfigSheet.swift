import SwiftUI

/// Captura lo único que el generador de plan necesita del usuario: cuántos días por semana puede
/// entrenar y (opcional) cuáles. Al cambiar, el plan y la "misión de hoy" se recalculan solos.
struct PlanConfigSheet: View {
    @Bindable var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detailDay: PlannedDay?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Días por semana: \(viewModel.planConfig.daysPerWeek)",
                            value: $viewModel.planConfig.daysPerWeek, in: 1...7)
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

                weekPreview
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
            .sheet(item: $detailDay) { day in
                WorkoutDetailView(day: day, viewModel: viewModel)
            }
        }
    }

    /// Vista previa en vivo de la semana con la config actual. Como el plan es derivado, cambia
    /// al instante al mover los días o los días preferidos — sin esperar a que llegue la fecha.
    @ViewBuilder private var weekPreview: some View {
        if let plan = viewModel.currentPlan {
            Section {
                ForEach(plan.days) { day in
                    Button { detailDay = day } label: {
                        HStack(spacing: 12) {
                            Image(systemName: day.kind.systemImage)
                                .foregroundStyle(Neon.accent).frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.weekdayName.capitalized)
                                    .font(.mCaption2).foregroundStyle(.secondary)
                                Text(day.label).font(.mSubheadline).foregroundStyle(.primary)
                                Text(day.detail).font(.mCaption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.mCaption2).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Vista previa de la semana")
            } footer: {
                if let note = plan.note {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Neon.orange)
                } else {
                    Text("Así queda tu semana con \(plan.days.count) "
                        + "\(plan.days.count == 1 ? "día" : "días") · "
                        + "\(Goal.trim(plan.totalKm)) km. Ajusta arriba y mira cómo cambia.")
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
