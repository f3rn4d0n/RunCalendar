import SwiftUI

/// Las preguntas que ningún dato responde.
///
/// La regla que decide qué está aquí: los **hechos del pasado** salen de Salud y no se preguntan
/// —cuánto corriste, si hubo un parón, tu tirada más larga—; la **intención y la capacidad** no
/// están en ningún sensor. Por eso son tres preguntas y no diez, y por eso la de kilómetros solo
/// aparece cuando no hay historial que mirar.
///
/// No bloquea nada: la app funciona sin responder y se ofrece desde *Ajustar*. Un muro en el
/// arranque cuesta usuarios, y cada respuesta mejora el plan por su cuenta.
struct IntakeSheet: View {
    @Bindable var viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    /// Texto del campo de km. Se edita como texto para no pelear con el teclado numérico.
    @State private var weeklyKmText = ""

    var body: some View {
        NavigationStack {
            Form {
                intentSection
                daysSection
                hillsSection
                if viewModel.needsDeclaredVolume { volumeSection }
            }
            .scrollContentBackground(.hidden)
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Afina tu plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        saveDeclaredVolume()
                        dismiss()
                    }
                }
            }
            .onAppear {
                weeklyKmText = viewModel.intake.declaredWeeklyKm.map { Goal.trim($0) } ?? ""
            }
        }
    }

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
            Text("Los que **puedes**, no los que entrenaste. La app ya sabe lo segundo; lo primero "
                + "solo lo sabes tú. Los días concretos se eligen en «Tu plan».")
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

    private var volumeSection: some View {
        Section {
            HStack {
                TextField("0", text: $weeklyKmText)
                    .keyboardType(.decimalPad)
                Text("km/semana").foregroundStyle(.secondary)
            }
        } header: {
            Text("¿Cuántos km corres a la semana?")
        } footer: {
            Text("Esto solo aparece porque **no encontramos carreras en Salud**. En cuanto registres "
                + "unas cuantas, el plan las usa y deja de preguntar. Si no corres todavía, déjalo "
                + "vacío y se empieza desde abajo.")
        }
    }

    /// El campo es texto para no pelear con el teclado; se traduce al salir. Vacío o ilegible se
    /// guarda como "no lo sé" y el motor cae a su arranque en frío, en vez de fabricar un cero.
    private func saveDeclaredVolume() {
        guard viewModel.needsDeclaredVolume else { return }
        let normalized = weeklyKmText.replacingOccurrences(of: ",", with: ".")
        let km = Double(normalized)
        viewModel.intake.declaredWeeklyKm = (km ?? 0) > 0 ? km : nil
    }
}
