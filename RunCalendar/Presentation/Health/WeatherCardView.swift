import SwiftUI

/// Tarjeta de clima reutilizable (carreras y entrenamientos). Carga async al aparecer
/// mediante el closure `load`; muestra el pronóstico/histórico a la hora del evento, o
/// el **motivo concreto** por el que no hay clima (ver `WeatherUnavailable`).
struct WeatherCardView: View {
    let load: () async -> Result<RaceWeather, WeatherUnavailable>

    @State private var result: Result<RaceWeather, WeatherUnavailable>?

    var body: some View {
        Group {
            switch result {
            case .none:
                HStack { ProgressView(); Text("Consultando el clima…").foregroundStyle(.secondary) }
            case .success(let weather):
                loaded(weather)
            case .failure(let reason):
                Label(reason.message, systemImage: reason.systemImage)
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
        .task { result = await load() }
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
