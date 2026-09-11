import SwiftUI

/// Tab "Plan": la semana completa — qué pide el plan, qué corriste, y por qué. Antes vivía
/// repartido entre la barra de *Hoy* (aviso + botón "ajustar") y un sheet aparte
/// (`WeekAdherenceView`); ahora es su propia pantalla y *Hoy* solo conserva la misión del día.
struct PlanView: View {
    @State var viewModel: GoalsViewModel
    @State private var showPlanConfig = false

    private var pauseMessage: (text: String, systemImage: String)? {
        viewModel.weekStatus.map { ($0.message, $0.systemImage) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let adherence = viewModel.weekAdherence {
                    WeekAdherenceView(
                        adherence: adherence,
                        outcomes: viewModel.weekOutcomes,
                        past: viewModel.pastWeeks,
                        pauseMessage: pauseMessage,
                        planNote: viewModel.currentPlan?.note
                    )
                } else {
                    EmptyStateView(
                        icon: "calendar",
                        title: "Sin plan todavía",
                        message: "Crea una meta de carrera en Objetivos y te armo un plan semanal automático."
                    )
                }
            }
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showPlanConfig = true } label: {
                        Label("\(viewModel.planConfig.daysPerWeek) días", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Ajustar días por semana")
                }
            }
            .sheet(isPresented: $showPlanConfig) {
                PlanConfigSheet(viewModel: viewModel)
            }
        }
    }
}
