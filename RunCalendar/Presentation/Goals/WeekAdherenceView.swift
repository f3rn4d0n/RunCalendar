import SwiftUI

/// La semana día por día: qué pedía el plan y qué corriste. Responde "¿por qué me faltaron
/// sesiones?" con el detalle que la barra de *Hoy* no cabe a mostrar.
struct WeekAdherenceView: View {
    let adherence: PlanAdherence
    let outcomes: [PlanDayOutcome]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(adherence.summary).font(.mHeadline)
                        ProgressView(value: adherence.fraction).tint(Neon.green)
                        Text("\(adherence.completedSessions)/\(adherence.plannedSessions) sesiones · "
                             + "\(Goal.trim(adherence.completedKm))/\(Goal.trim(adherence.plannedKm)) km"
                             + (adherence.completedMinutes > 0 ? " · \(adherence.completedMinutes) min" : ""))
                            .font(.mCaption.monospacedDigit()).foregroundStyle(.secondary)
                        if adherence.plannedHardSessions > 0 {
                            Text("Calidad: \(adherence.completedHardSessions) de "
                                 + "\(adherence.plannedHardSessions) sesiones (tempo/series)")
                                .font(.mCaption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let warning = adherence.extraLoadWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.mSubheadline).foregroundStyle(Neon.orange)
                    }
                }

                Section("Día por día") {
                    ForEach(outcomes) { outcome in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: icon(outcome.status))
                                .foregroundStyle(color(outcome.status))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(outcome.weekdayName.capitalized).font(.mSubheadline)
                                Text(outcome.summary).font(.mCaption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section {
                    Text("Una sesión cuenta como de calidad por tu **RPE** (7 o más), no por el día: "
                         + "así vale igual si moviste el tempo del martes al jueves. El kilometraje "
                         + "cuenta como cumplido desde el 90% del objetivo — nadie clava el número "
                         + "exacto.")
                        .font(.mCaption2).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Neon.surface)
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Tu semana")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } }
            }
        }
    }

    private func icon(_ status: PlanDayOutcome.Status) -> String {
        switch status {
        case .done:     return "checkmark.circle.fill"
        case .partial:  return "circle.lefthalf.filled"
        case .missed:   return "xmark.circle"
        case .extra:    return "exclamationmark.circle"
        case .rest:     return "moon.zzz"
        case .upcoming: return "clock"
        }
    }

    private func color(_ status: PlanDayOutcome.Status) -> Color {
        switch status {
        case .done:              return Neon.green
        case .partial:           return Neon.gold
        case .missed, .extra:    return Neon.orange
        case .rest, .upcoming:   return .secondary
        }
    }
}
