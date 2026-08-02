import SwiftUI
import WorkoutKit

/// Explica una sesión del plan al tocarla: qué es, cómo se hace (con esquema de repeticiones),
/// para qué sirve y por qué ese número. Convierte "Series 3.3 km" en algo accionable — y con
/// "Enviar al Apple Watch", en algo **ejecutable**.
struct WorkoutDetailView: View {
    let day: PlannedDay
    let viewModel: GoalsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingWatchPreview = false

    private var guide: WorkoutGuide { viewModel.guide(for: day) }

    /// `nil` en Mac o si la sesión no tiene bloques: el botón simplemente no aparece.
    private var watchPlan: WorkoutPlan? {
        WatchWorkoutBuilder.plan(for: guide, displayName: "\(guide.title) · \(guide.headline)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    if day.isFixed { fixedDayBanner }
                    howTo
                    if let watchPlan { sendToWatch(watchPlan) }
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

    /// Un día de carrera no es una sugerencia editable: ya hay una inscripción de por medio.
    /// Se dice explícitamente para que no parezca que el plan se equivocó al no ofrecer cambiarlo.
    private var fixedDayBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill").font(.mCaption).foregroundStyle(Neon.gold)
            Text(day.targetKm.map {
                "Día fijo: estás inscrito a esta carrera de \(Goal.trim($0)) km. "
                    + "El resto de la semana se acomoda alrededor."
            } ?? "Día fijo: estás inscrito a esta carrera. Captura su distancia para que el plan "
                + "ajuste tu volumen de la semana.")
                .font(.mCaption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Neon.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
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

    /// El reloj se encarga del resto: háptico y voz al cerrar cada repetición, y avance solo.
    private func sendToWatch(_ plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Haptics.light()
                Usage.workoutSentToWatch(kind: day.kind)
                showingWatchPreview = true
            } label: {
                Label("Enviar al Apple Watch", systemImage: "applewatch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeonButtonStyle())
            Text("El reloj te avisa con vibración al cerrar cada tramo y avanza solo.")
                .font(.mCaption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .workoutPreview(plan, isPresented: $showingWatchPreview)
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
