import SwiftUI

/// Tarjeta de clima reutilizable (carreras y entrenamientos). Carga async al aparecer
/// mediante el closure `load`; muestra el pronóstico/histórico a la hora del evento,
/// o `emptyMessage` si aún no hay datos (fecha muy a futuro o sin ubicación).
struct WeatherCardView: View {
    var emptyMessage = "No pudimos obtener el clima para esta ubicación. Revisa que la dirección sea reconocible."
    let load: () async -> RaceWeather?

    @State private var weather: RaceWeather?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                HStack { ProgressView(); Text("Consultando el clima…").foregroundStyle(.secondary) }
            } else if let weather {
                loaded(weather)
            } else {
                Label(emptyMessage, systemImage: "clock.badge.questionmark")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
        .task {
            weather = await load()
            isLoading = false
        }
    }

    private func loaded(_ w: RaceWeather) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 2) {
                    Image(systemName: w.condition.systemImage)
                        .font(.system(size: 34))
                        .foregroundStyle(Neon.accent)
                    Text("\(Int(w.temperatureC.rounded()))°")
                        .font(.mLargeTitle.bold())
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(w.condition.label).font(.mHeadline)
                    detail("Sensación \(Int(w.apparentTemperatureC.rounded()))°", icon: "thermometer.medium")
                    detail("Humedad \(w.humidity)%", icon: "humidity.fill")
                    detail("Viento \(Int(w.windKmh.rounded())) km/h", icon: "wind")
                    if let precip = w.precipitationProbability {
                        detail("Prob. de lluvia \(precip)%", icon: "umbrella.fill")
                    }
                }
                Spacer()
            }
            Label(w.kind.legend, systemImage: w.kind == .estimate ? "exclamationmark.circle" : "info.circle")
                .font(.mCaption2)
                .foregroundStyle(w.kind == .estimate ? AnyShapeStyle(Neon.orange) : AnyShapeStyle(.tertiary))
        }
        .padding(.vertical, 4)
    }

    private func detail(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.mSubheadline)
            .foregroundStyle(.secondary)
    }
}
