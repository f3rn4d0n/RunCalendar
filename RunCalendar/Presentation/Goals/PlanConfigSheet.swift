import SwiftUI

/// Captura lo único que el generador de plan necesita del usuario: cuántos días por semana puede
/// entrenar y (opcional) cuáles. Al cambiar, el plan y la "misión de hoy" se recalculan solos.
struct PlanConfigSheet: View {
    @Bindable var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detailDay: PlannedDay?
    @State private var suggestion: PlanSuggestion?
    @State private var noHistory = false
    /// Config al abrir la hoja, para mandar **un** evento al cerrar en vez de uno por toque del
    /// stepper (subir de 3 a 7 días son cuatro cambios y una sola decisión).
    @State private var configAtOpen: PlanConfig?
    @State private var usedSuggestion = false
    /// Qué semana se está mirando: 0 la actual, 1 la próxima. Planificar un sábado no es planificar
    /// el sábado — es planificar la semana que viene, y hasta ahora no había forma de verla.
    @State private var weekOffset = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        if let s = viewModel.planSuggestion() { suggestion = s } else { noHistory = true }
                    } label: {
                        Label("Sugerir plan desde mi historial", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(NeonButtonStyle())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Analiza tus corridas recientes para proponerte días/semana, tus días y una "
                        + "meta de volumen. Todo queda editable.")
                }

                Section {
                    Stepper("Días por semana: \(viewModel.planConfig.daysPerWeek)",
                            value: $viewModel.planConfig.daysPerWeek, in: 1...7)
                } footer: {
                    Text("Cuántas veces puedes correr en la semana. El plan reparte tirada larga, "
                        + "tempo y series según esto.")
                }

                weekStatusSection

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
                    Button("Listo") {
                        reportConfigChange()
                        dismiss()
                    }
                }
            }
            .onAppear {
                configAtOpen = viewModel.planConfig
                // Si de esta semana quedan menos días de los que entrenas, lo que estás
                // planificando es la siguiente — se abre ahí en vez de en un muñón de un día.
                if let plan = viewModel.plan(weekOffset: 0),
                   7 - plan.plansFrom < viewModel.planConfig.daysPerWeek {
                    weekOffset = 1
                }
            }
            .sheet(item: $detailDay) { day in
                WorkoutDetailView(day: day, viewModel: viewModel)
            }
            .alert("Plan sugerido", isPresented: Binding(
                get: { suggestion != nil },
                set: { if !$0 { suggestion = nil } }
            )) {
                Button("Aplicar") {
                    if let s = suggestion {
                        usedSuggestion = true
                        Task { await viewModel.applyPlanSuggestion(s) }
                    }
                    suggestion = nil
                }
                Button("Cancelar", role: .cancel) { suggestion = nil }
            } message: {
                Text(suggestion?.rationale ?? "")
            }
            .alert("Sin historial suficiente", isPresented: $noHistory) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text("Corre unas cuantas veces (y deja que Salud las importe) para poder sugerirte "
                    + "un plan desde tu historial.")
            }
        }
    }

    /// Marcar la semana cuando no se puede (o no se debe) entrenar. Pausa la adherencia en vez de
    /// dejar que marque 0% a alguien que hizo lo correcto al no correr.
    @ViewBuilder private var weekStatusSection: some View {
        Section {
            Picker("Esta semana", selection: $viewModel.weekStatus) {
                Text("Normal").tag(WeekStatus?.none)
                ForEach(WeekStatus.allCases) { status in
                    Label(status.displayName, systemImage: status.systemImage)
                        .tag(Optional(status))
                }
            }
            if let status = viewModel.weekStatus {
                Text(status.hint).font(.mCaption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Estado de la semana")
        } footer: {
            Text(viewModel.weekStatus == nil
                 ? "Si te lesionas, te enfermas o toca semana de descarga, márcalo aquí: la "
                   + "adherencia se pausa en vez de contarte como semana fallada."
                 : "La adherencia está en pausa. Vuelve a «Normal» cuando retomes el plan — al "
                   + "empezar la semana siguiente se limpia solo.")
        }
    }

    /// Vista previa en vivo de la semana con la config actual. Como el plan es derivado, cambia
    /// al instante al mover los días o los días preferidos — sin esperar a que llegue la fecha.
    @ViewBuilder private var weekPreview: some View {
        if let plan = viewModel.plan(weekOffset: weekOffset) {
            Section {
                Picker("Semana", selection: $weekOffset) {
                    Text("Esta semana").tag(0)
                    Text("La próxima").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                let doneKm = viewModel.doneKmByWeekday(for: plan)
                ForEach(plan.fullWeek(), id: \.weekday) { entry in
                    // Los días que ya pasaron se pintan con lo que **de verdad corriste**, no con
                    // lo que se hubiera planeado: el plan no se guarda, así que "el plan que tenías"
                    // no existe — pero lo que hiciste sí, y para revisar la semana sirve más.
                    if PlannedDay.position(of: entry.weekday) < plan.plansFrom {
                        pastRow(weekday: entry.weekday, km: doneKm[entry.weekday] ?? 0)
                    } else if let day = entry.session {
                        Button { detailDay = day } label: { sessionRow(day) }
                            .buttonStyle(.plain)
                    } else {
                        restRow(weekday: entry.weekday)
                    }
                }
            } header: {
                Text("Vista previa de la semana")
            } footer: {
                if let note = plan.note {
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Neon.orange)
                } else {
                    Text(previewFooter(plan))
                }
            }
        }
    }

    private func sessionRow(_ day: PlannedDay) -> some View {
        // Los días de carrera se distinguen a propósito: el atleta tiene que ver de un vistazo
        // cuáles puede mover con los controles de arriba y cuál ya no.
        HStack(spacing: 12) {
            Image(systemName: day.kind.systemImage)
                .foregroundStyle(day.isFixed ? Neon.gold : Neon.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(day.weekdayName.capitalized).font(.mCaption2).foregroundStyle(.secondary)
                    if day.isFixed {
                        Image(systemName: "lock.fill").font(.system(size: 8))
                            .foregroundStyle(Neon.gold)
                    }
                }
                Text(day.label).font(.mSubheadline).foregroundStyle(.primary)
                Text(day.detail).font(.mCaption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.mCaption2).foregroundStyle(.tertiary)
        }
    }

    /// Un día que ya pasó: hecho consumado, no una sugerencia. Sin chevron ni acción — no hay nada
    /// que abrir ni que editar de un día que ya viviste.
    private func pastRow(weekday: Int, km: Double) -> some View {
        let name = (1...7).contains(weekday) ? Calendar.current.weekdaySymbols[weekday - 1] : "—"
        let ran = km > 0
        return HStack(spacing: 12) {
            Image(systemName: ran ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(ran ? AnyShapeStyle(Neon.green) : AnyShapeStyle(.tertiary))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized).font(.mCaption2).foregroundStyle(.tertiary)
                Text(ran ? "\(Goal.trim(km)) km corridos" : "Sin correr")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func restRow(weekday: Int) -> some View {
        let name = (1...7).contains(weekday) ? Calendar.current.weekdaySymbols[weekday - 1] : "—"
        return HStack(spacing: 12) {
            Image(systemName: "moon.zzz").foregroundStyle(.tertiary).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.capitalized).font(.mCaption2).foregroundStyle(.secondary)
                Text("Descanso").font(.mSubheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var weekdayPicker: some View {
        let symbols = Calendar.current.shortWeekdaySymbols   // 1=Dom … 7=Sáb
        // Recorrido por **posición** para que las fichas salgan L M M J V S D, en el mismo orden
        // que la vista previa de abajo y que el resto de la app.
        let week = (0...6).map { PlannedDay.weekday(atPosition: $0) }
        return HStack(spacing: 6) {
            ForEach(week, id: \.self) { weekday in
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

    /// Resumen de la semana previsualizada. Extraído a función porque interpolado en la vista el
    /// compilador de SwiftUI no lo resuelve en tiempo razonable.
    private func previewFooter(_ plan: TrainingPlan) -> String {
        let unit = plan.days.count == 1 ? "día" : "días"
        var text = "Así queda tu semana con \(plan.days.count) \(unit) · "
        text += "\(Goal.trim(plan.totalKm)) km. Ajusta arriba y mira cómo cambia."
        if plan.plansFrom > 0 {
            text += " Esta semana ya empezó: solo se proponen los días que quedan. "
            text += "Mira «La próxima» para ver la semana completa."
        }
        return text
    }

    /// Un evento por visita a la hoja, y solo si algo cambió: abrir para mirar el plan y cerrar no
    /// es haberlo configurado.
    private func reportConfigChange() {
        guard let configAtOpen, configAtOpen != viewModel.planConfig else { return }
        Usage.planConfigured(daysPerWeek: viewModel.planConfig.daysPerWeek,
                             fromSuggestion: usedSuggestion)
    }
}
