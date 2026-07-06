import SwiftUI

/// Pantalla de condición física: conecta con Salud, muestra el resumen y el
/// estimado de preparación por distancia.
struct HealthView: View {
    @State var viewModel: HealthViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .unavailable:
                    EmptyStateView(
                        icon: "heart.slash",
                        title: "No disponible aquí",
                        message: "La condición física con Apple Salud está disponible en tu iPhone."
                    )
                case .needsAuthorization:
                    connectPrompt
                case .loading:
                    ProgressView("Leyendo Salud…")
                case .loaded(let summary, let readiness):
                    loaded(summary: summary, readiness: readiness)
                case .error(let message):
                    VStack(spacing: 16) {
                        EmptyStateView(icon: "exclamationmark.triangle", title: "Ups", message: message)
                        Button("Reintentar") { Task { await viewModel.connect() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("Condición")
            .task { await viewModel.onAppear() }
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(Neon.logoGradient)
            Text("Conecta con Apple Salud para ver tu condición y saber si estás listo para tu próxima carrera.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Conectar con Salud") { Task { await viewModel.connect() } }
                .buttonStyle(NeonButtonStyle())
                .padding(.horizontal, 40)
        }
        .padding()
    }

    private func loaded(summary: FitnessSummary, readiness: [RaceReadiness]) -> some View {
        List {
            summarySection(summary)

            Section {
                ForEach(readiness) { item in
                    NavigationLink {
                        ReadinessDetailView(readiness: item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.level.systemImage)
                                .foregroundStyle(color(for: item.level))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.distance.displayName) · \(item.level.rawValue)")
                                Text(item.note).font(.mCaption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("¿Listo para…?")
            } footer: {
                Text("Toca una distancia para ver qué mejorar. Estimado orientativo, no es consejo médico.")
            }

            Section {
                Button("Actualizar") { Task { await viewModel.load() } }
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ summary: FitnessSummary) -> some View {
        Section("Resumen (\(summary.weeks) semanas)") {
            MetricRow(label: "Esta semana (7 días)", value: km(summary.last7DaysKm), icon: "calendar",
                      info: HealthMetricInfo.thisWeek())
            MetricRow(label: "Promedio semanal (\(summary.weeks) sem)",
                      value: km(summary.weeklyDistanceKm), icon: "chart.bar.fill",
                      info: HealthMetricInfo.weeklyAverage(weeks: summary.weeks))
            MetricRow(label: "Carrera más larga", value: km(summary.longestRunKm), icon: "figure.run",
                      info: HealthMetricInfo.longestRun())
            MetricRow(label: "Entrenamientos", value: "\(summary.runCount)", icon: "number",
                      info: HealthMetricInfo.runCount())
            if let vo2 = summary.vo2Max {
                MetricRow(label: "VO₂max", value: vo2.formatted(.number.precision(.fractionLength(1))),
                          icon: "lungs.fill",
                          info: HealthMetricInfo.vo2Max(vo2, age: summary.age))
            }
            if let resting = summary.restingHeartRate {
                MetricRow(label: "FC en reposo", value: "\(Int(resting)) lpm", icon: "heart.fill",
                          info: HealthMetricInfo.restingHeartRate(resting))
            }
        }
    }

    private func km(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) km"
    }

    private func color(for level: ReadinessLevel) -> Color {
        switch level {
        case .ready: return Neon.green
        case .almost: return Neon.gold
        case .building: return Neon.orange
        }
    }
}
