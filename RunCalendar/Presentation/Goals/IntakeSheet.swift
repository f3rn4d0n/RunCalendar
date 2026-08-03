import SwiftUI

/// Un solo flujo para armar tu plan: **te enseña lo que ya sabemos, te pregunta lo que no se ve, y
/// propone la meta de volumen.**
///
/// Antes eran dos botones —"Sugerir plan desde mi historial" y la entrevista— que sonaban a lo
/// mismo y, peor, **escribían el mismo campo**: los dos fijaban `daysPerWeek`, uno desde el
/// historial y otro desde tus respuestas, ganando el último que corrieras. Responder la entrevista
/// y luego pulsar sugerir borraba tu respuesta sin decir nada.
///
/// La distinción que sí importa se conserva, pero como **secciones de un mismo relato** en vez de
/// como botones rivales: los hechos del pasado se observan (y se pueden corregir), la intención y
/// la capacidad se declaran. Ver *Lo que el motor no puede saber* en
/// `docs/motor-de-entrenamiento.md`.
///
/// No bloquea nada: la app funciona sin abrirla.
struct IntakeSheet: View {
    @Bindable var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    /// Texto del campo de km. Se edita como texto para no pelear con el teclado numérico.
    @State private var weeklyKmText = ""
    /// Si el atleta acepta la meta de volumen propuesta.
    @State private var acceptVolumeGoal = false

    private var suggestion: PlanSuggestion? { viewModel.planSuggestion() }

    var body: some View {
        NavigationStack {
            Form {
                observedSection
                intentSection
                daysSection
                hillsSection
                if let suggestion { volumeGoalSection(suggestion) }
            }
            .scrollContentBackground(.hidden)
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Afina tu plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { Task { await apply() } }
                }
            }
            .onAppear(perform: prefill)
        }
    }

    // MARK: - Lo que ya sabemos

    /// Primero lo observado, y luego las preguntas. El orden es el mensaje: *esto es lo que veo de
    /// ti; corrígeme y dime lo que no puedo ver*.
    @ViewBuilder private var observedSection: some View {
        Section {
            if viewModel.observed.hasHistory {
                observedRow("Corres", value: observedDaysText)
                observedRow("Tu volumen", value: "\(Goal.trim(viewModel.observed.weeklyKm)) km/semana")
                if let long = viewModel.observed.longestRunKm {
                    observedRow("Tu tirada más larga", value: "\(Goal.trim(long)) km")
                }
            } else {
                HStack {
                    TextField("0", text: $weeklyKmText).keyboardType(.decimalPad)
                    Text("km/semana").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(viewModel.observed.hasHistory ? "Lo que vemos de ti" : "¿Cuántos km corres a la semana?")
        } footer: {
            Text(viewModel.observed.hasHistory
                 ? "Sale de tus carreras en Salud, así que no hace falta que lo escribas. Si no te "
                   + "cuadra —corriste años antes de tener reloj, o hay carreras de otra persona— "
                   + "ajusta abajo los días y la meta de volumen: el plan usa lo que le digas."
                 : "**No encontramos carreras en Salud**, así que esto es lo único que el plan tiene "
                   + "para empezar. En cuanto registres unas cuantas deja de preguntarlo. Si no "
                   + "corres todavía, déjalo vacío y se empieza desde abajo.")
        }
    }

    private func observedRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(Neon.accent)
        }
        .font(.mSubheadline)
    }

    private var observedDaysText: String {
        guard let days = viewModel.observed.daysPerWeek else { return "—" }
        return "\(days) \(days == 1 ? "día" : "días")/semana"
    }

    // MARK: - Lo que no se ve

    private var intentSection: some View {
        Section {
            Picker("Qué buscas", selection: $viewModel.intake.intent) {
                ForEach(TrainingIntent.allCases) { intent in
                    Text(intent.displayName).tag(intent)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("¿Qué buscas?")
        } footer: {
            Text(viewModel.intake.intent.hint + "\n\n"
                + "Cambia la forma de la semana, no solo el tono: terminar una distancia se "
                + "construye con volumen y tirada larga, y mantener la forma se sostiene con la "
                + "intensidad, no con los kilómetros.")
        }
    }

    private var daysSection: some View {
        Section {
            Stepper("Días por semana: \(viewModel.planConfig.daysPerWeek)",
                    value: $viewModel.planConfig.daysPerWeek, in: 1...7)
        } header: {
            Text("¿Cuántos días puedes entrenar?")
        } footer: {
            Text(viewModel.observed.daysPerWeek.map {
                "Vienes entrenando \($0). Pero lo que el plan necesita es cuántos **puedes** — una "
                + "mala racha no es tu disponibilidad, y una buena tampoco es una promesa."
            } ?? "Los días concretos se eligen en «Tu plan».")
        }
    }

    private var hillsSection: some View {
        Section {
            Toggle("Tengo una cuesta cerca", isOn: $viewModel.intake.hasHills)
        } header: {
            Text("¿Tienes dónde hacer cuestas?")
        } footer: {
            Text("Una pendiente suave y continua que puedas **subir corriendo un minuto seguido** "
                + "— unos 200–300 m, de las que se suben trotando sin ahogarte a los diez segundos. "
                + "Un puente, una calle en subida o una cinta con inclinación sirven.\n\n"
                + "Unas escaleras no: la zancada es otra y no se pueden bajar al trote, que es "
                + "justo la recuperación entre repeticiones.\n\n"
                + "Si no tienes, esa sesión sale de la rotación y su sitio lo ocupan las otras.")
        }
    }

    // MARK: - La meta que sí sale del historial

    private func volumeGoalSection(_ suggestion: PlanSuggestion) -> some View {
        Section {
            Toggle("Poner mi meta en \(Goal.trim(suggestion.weeklyVolumeTarget)) km/sem",
                   isOn: $acceptVolumeGoal)
        } header: {
            Text("Meta de volumen")
        } footer: {
            // El impacto va primero: es lo que puede hacerte decir que no.
            Text([viewModel.suggestionImpact(suggestion), suggestion.rationale]
                .compactMap { $0 }.joined(separator: "\n\n"))
        }
    }

    // MARK: - Aplicar

    private func prefill() {
        weeklyKmText = viewModel.intake.declaredWeeklyKm.map { Goal.trim($0) } ?? ""
        // Los días arrancan en lo observado: casi siempre es la respuesta correcta, y así responder
        // la entrevista sin tocar nada no empeora tu plan.
        if !viewModel.hasAnsweredIntake, let days = viewModel.observed.daysPerWeek {
            viewModel.planConfig.daysPerWeek = days
        }
    }

    /// El campo de km es texto para no pelear con el teclado; se traduce al salir. Vacío o ilegible
    /// se guarda como "no lo sé" y el motor cae a su arranque en frío, en vez de fabricar un cero.
    private func apply() async {
        if !viewModel.observed.hasHistory {
            let km = Double(weeklyKmText.replacingOccurrences(of: ",", with: "."))
            viewModel.intake.declaredWeeklyKm = (km ?? 0) > 0 ? km : nil
        }
        if acceptVolumeGoal, let suggestion {
            await viewModel.applyVolumeGoal(from: suggestion)
        }
        dismiss()
    }
}
