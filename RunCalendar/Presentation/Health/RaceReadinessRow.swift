import SwiftUI

/// Fila de preparación para una carrera: nivel, tiempo restante y qué mejorar.
/// Reutilizada en Condición (lista de prioritarias) y en el detalle de la carrera.
struct RaceReadinessRow: View {
    let race: Race
    let readiness: RaceReadiness

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: readiness.level.systemImage)
                .font(.system(size: 30))
                .foregroundStyle(color)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(race.name).font(.mHeadline).lineLimit(1)
                    Text(readiness.level.rawValue)
                        .font(.mCaption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(color.opacity(0.15), in: Capsule())
                        .foregroundStyle(color)
                }
                Text("\(race.discipline.displayName) · \(timeToRace)")
                    .font(.mCaption).foregroundStyle(.secondary)
                Text(readiness.note).font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var color: Color {
        switch readiness.level {
        case .ready:    return Neon.green
        case .almost:   return Neon.gold
        case .building: return Neon.orange
        }
    }

    /// "faltan ~6 semanas" para eventos lejanos; la cuenta regresiva en días si es cercano.
    private var timeToRace: String {
        let days = race.date.daysFromNow()
        if days >= 14 { return "faltan ~\(days / 7) semanas" }
        return race.date.countdownText().lowercased()
    }
}
