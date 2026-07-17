import SwiftUI

/// Parciales por kilómetro: tiempo, FC promedio y una barra relativa (más largo = más rápido).
struct SplitsView: View {
    let splits: [Split]
    @Environment(\.dismiss) private var dismiss

    /// El km más rápido (menos segundos), para escalar las barras.
    private var fastest: Int { splits.map(\.seconds).min() ?? 1 }

    var body: some View {
        NavigationStack {
            List(splits) { split in
                HStack(spacing: 12) {
                    Text("KM \(split.km)")
                        .font(.mSubheadline.weight(.semibold).monospacedDigit())
                        .frame(width: 52, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(split.paceText) /km").font(.mHeadline.monospacedDigit())
                            if split.km == fastestKm {
                                Image(systemName: "bolt.fill").font(.mCaption2).foregroundStyle(Neon.gold)
                                    .accessibilityLabel("Km más rápido")
                            }
                            Spacer()
                            if let hr = split.avgHeartRate {
                                Label("\(hr)", systemImage: "heart.fill")
                                    .font(.mCaption).foregroundStyle(Neon.orange)
                            }
                        }
                        // Barra relativa: el km más rápido llena la barra.
                        GeometryReader { geo in
                            Capsule()
                                .fill(Neon.accent)
                                .frame(width: geo.size.width * barFraction(split))
                        }
                        .frame(height: 6)
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationTitle("Parciales por km")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } }
            }
        }
    }

    private var fastestKm: Int {
        splits.min { $0.seconds < $1.seconds }?.km ?? 0
    }

    /// Fracción de barra: el más rápido = 1.0; los demás, proporcionalmente menos.
    private func barFraction(_ split: Split) -> Double {
        guard split.seconds > 0 else { return 1 }
        return Double(fastest) / Double(split.seconds)
    }
}
