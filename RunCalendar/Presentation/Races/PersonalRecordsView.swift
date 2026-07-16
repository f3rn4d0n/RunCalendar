import SwiftUI

/// Récords personales por distancia (5K/10K/21K/42K), juntando carreras y entrenamientos:
/// mejor esfuerzo (por ritmo), velocidad promedio y progresión.
struct PersonalRecordsView: View {
    let racesViewModel: RacesViewModel
    let trainingViewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss

    private let distances: [RaceDiscipline] = [.fiveK, .tenK, .halfMarathon, .marathon]

    private var records: [PersonalRecord] {
        PersonalRecords.compute(races: racesViewModel.races, sessions: trainingViewModel.sessions)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(distances) { distance in
                    Section(distance.displayName) {
                        if let record = records.first(where: { $0.distance == distance }) {
                            recordContent(record)
                        } else {
                            Label("Aún sin registro. Captura una carrera \(distance.displayName) con su tiempo, "
                                + "o importa un entrenamiento de esa distancia.",
                                  systemImage: "hourglass")
                                .font(.mSubheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Récords")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func recordContent(_ r: PersonalRecord) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.best.timeSeconds.durationString())
                    .font(.mLargeTitle.bold()).foregroundStyle(.tint).monospacedDigit()
                Text("\(speedText(r.best.speedKmh)) · \(paceText(r.best.paceSecondsPerKm)) /km")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "medal.fill").font(.system(size: 30)).foregroundStyle(Neon.gold)
        }

        HStack(spacing: 8) {
            sourceBadge(r.best.source)
            Text(r.best.name).font(.mSubheadline).lineLimit(1)
            Spacer()
            Text(r.best.date.mediumString()).font(.mCaption).foregroundStyle(.secondary)
        }

        if r.history.count > 1 {
            DisclosureGroup("Progresión · \(r.history.count) esfuerzos") {
                ForEach(r.history.reversed()) { effort in
                    historyRow(effort, isBest: effort.id == r.best.id)
                }
            }
        }
    }

    private func historyRow(_ effort: RunEffort, isBest: Bool) -> some View {
        HStack(spacing: 10) {
            sourceBadge(effort.source)
            VStack(alignment: .leading, spacing: 1) {
                Text(effort.date.mediumString()).font(.mCaption).foregroundStyle(.secondary)
                Text("\(effort.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                    .font(.mCaption2).foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(effort.timeSeconds.durationString()).font(.mSubheadline.monospacedDigit())
                Text(speedText(effort.speedKmh)).font(.mCaption2).foregroundStyle(.secondary)
            }
            if isBest {
                Image(systemName: "medal.fill").font(.mCaption).foregroundStyle(Neon.gold)
                    .accessibilityLabel("Récord")
            }
        }
    }

    private func sourceBadge(_ source: RunEffort.Source) -> some View {
        let isRace = source == .race
        return Text(isRace ? "Carrera" : "Entreno")
            .font(.mCaption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((isRace ? Neon.accent : Neon.teal).opacity(0.15), in: Capsule())
            .foregroundStyle(isRace ? Neon.accent : Neon.teal)
    }

    private func speedText(_ kmh: Double) -> String {
        "\(kmh.formatted(.number.precision(.fractionLength(1)))) km/h"
    }

    private func paceText(_ secondsPerKm: Int) -> String {
        String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }
}
