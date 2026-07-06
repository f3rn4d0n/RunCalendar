import SwiftUI

/// Detalle de preparación para una distancia: nivel, progreso y qué mejorar.
struct ReadinessDetailView: View {
    let readiness: RaceReadiness

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: readiness.level.systemImage)
                        .font(.system(size: 36))
                        .foregroundStyle(levelColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(readiness.distance.displayName).font(.mTitle3)
                        Text(readiness.level.rawValue).foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section("Tu progreso") {
                progressRow(
                    title: "Carrera más larga",
                    current: readiness.currentLongRunKm,
                    target: readiness.recommendedLongRunKm
                )
                progressRow(
                    title: "Volumen semanal (prom.)",
                    current: readiness.currentWeeklyKm,
                    target: readiness.recommendedWeeklyKm
                )
            }

            Section {
                ForEach(readiness.recommendations, id: \.self) { rec in
                    Label {
                        Text(rec)
                    } icon: {
                        Image(systemName: "checkmark.circle").foregroundStyle(.tint)
                    }
                }
            } header: {
                Text("Para estar listo")
            } footer: {
                Text("Estimado orientativo a partir de tus datos de Salud. No es consejo médico.")
            }
        }
        .navigationTitle("Listo para \(readiness.distance.displayName)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var levelColor: Color {
        switch readiness.level {
        case .ready: return Neon.green
        case .almost: return Neon.gold
        case .building: return Neon.orange
        }
    }

    private func progressRow(title: String, current: Double, target: Double) -> some View {
        let fraction = target > 0 ? min(current / target, 1) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(km(current)) / \(km(target))")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: fraction).tint(levelColor)
        }
    }

    private func km(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) km"
    }
}
