import SwiftUI

/// La semana día por día: qué pedía el plan y qué corriste. Responde "¿por qué me faltaron
/// sesiones?" con el detalle que la barra de *Hoy* no cabe a mostrar.
struct WeekAdherenceView: View {
    let adherence: PlanAdherence
    let outcomes: [PlanDayOutcome]
    /// Semanas ya cerradas, de la más reciente a la más vieja. Vacío mientras no haya historial.
    var past: [(plan: TrainingPlan, adherence: PlanAdherence)] = []
    @Environment(\.dismiss) private var dismiss

    /// Las semanas anteriores con lo que pidieron y lo que hiciste.
    ///
    /// Solo es posible desde que el plan de cada semana se guarda: regenerarlo hoy daría otro,
    /// porque depende de tu volumen actual — y te estaríamos midiendo contra un plan que nunca
    /// viste. Es la razón de fondo para persistirlo, más que la comodidad.
    @ViewBuilder private var pastWeeksSection: some View {
        if !past.isEmpty {
            Section {
                ForEach(past, id: \.plan.id) { week in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weekLabel(week.plan.weekStart)).font(.mSubheadline)
                            Text("\(week.adherence.completedSessions)/\(week.adherence.plannedSessions) sesiones · "
                                 + "\(Goal.trim(week.adherence.completedKm))/\(Goal.trim(week.adherence.plannedKm)) km")
                                .font(.mCaption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(week.adherence.fraction * 100))%")
                            .font(.marker(16))
                            .foregroundStyle(week.adherence.fraction >= 0.8 ? Neon.green : Neon.gold)
                    }
                }
            } header: {
                Text("Semanas anteriores")
            } footer: {
                SectionNote("Cada semana se mide contra el plan que tenías **entonces**, no contra "
                            + "el de hoy. Por eso el plan de la semana se guarda al empezarla.")
            }
        }
    }

    private func weekLabel(_ start: Date) -> String {
        let end = Calendar.app.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(start.formatted(.dateTime.day().month(.abbreviated))) – "
            + "\(end.formatted(.dateTime.day().month(.abbreviated)))"
    }

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

                pastWeeksSection
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
