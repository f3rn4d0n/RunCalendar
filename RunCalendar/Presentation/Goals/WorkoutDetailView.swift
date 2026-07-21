import SwiftUI

/// Explica una sesión del plan al tocarla: qué es, cómo se hace (con esquema de repeticiones),
/// para qué sirve y por qué ese número. Convierte "Series 3.3 km" en algo accionable.
struct WorkoutDetailView: View {
    let day: PlannedDay
    let viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss

    private var guide: WorkoutGuide { viewModel.guide(for: day) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    howTo
                    DashCard(eyebrow: "Para qué sirve", accent: Neon.teal) {
                        Text(guide.purpose).font(.mSubheadline).foregroundStyle(.secondary)
                    }
                    DashCard(eyebrow: "¿Por qué este número?", accent: Neon.purple) {
                        Text(guide.rationale).font(.mSubheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle(day.weekdayName.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: day.kind.systemImage).font(.title).foregroundStyle(Neon.accent)
                Text(guide.title).font(.mTitle3)
            }
            Text(guide.headline).font(.marker(26)).foregroundStyle(Neon.accent)
            Label(guide.pace, systemImage: "gauge.medium")
                .font(.mCaption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var howTo: some View {
        DashCard(eyebrow: "Cómo se hace", accent: Neon.green) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(guide.steps, id: \.label) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "circle.fill").font(.system(size: 6))
                            .foregroundStyle(Neon.green).padding(.top, 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.label).font(.mHeadline)
                            Text(step.detail).font(.mSubheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
