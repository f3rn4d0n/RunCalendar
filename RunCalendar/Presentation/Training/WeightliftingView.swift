import SwiftUI

/// Lista de ejercicios con su mejor resultado (récord fusionado de WOD + registros sueltos).
/// El selector de arriba deja registrar el primer resultado de cualquier ejercicio, aunque todavía
/// no tenga récord y por eso no aparezca en la lista.
struct WeightliftingView: View {
    let viewModel: WeightliftingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedExercise: StrengthExercise = .sentadilla
    @State private var addingNew = false

    private var records: [LiftRecord] { viewModel.records }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "Sin resultados todavía",
                        message: "Elige un ejercicio arriba y registra tu primer resultado."
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            NavigationLink {
                                LiftDetailView(weightliftingViewModel: viewModel, exercise: record.exercise)
                            } label: {
                                HStack {
                                    Text(record.exercise.displayName)
                                    Spacer()
                                    Text(heroText(record.best)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listRowBackground(Neon.surface)
                }
            }
            .background(Neon.background.ignoresSafeArea())
            .safeAreaInset(edge: .top) { componentPicker }
            .navigationTitle("Pesas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } }
            }
            .sheet(isPresented: $addingNew) {
                LiftEntrySheet(weightliftingViewModel: viewModel, exercise: selectedExercise, effort: nil)
            }
        }
    }

    private var componentPicker: some View {
        HStack {
            Picker("Seleccione un componente", selection: $selectedExercise) {
                ForEach(StrengthExercise.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            Spacer()
            Button { addingNew = true } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .accessibilityLabel("Registrar resultado")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Neon.surface)
    }

    private func heroText(_ effort: LiftEffort) -> String {
        effort.exercise.loadStyle == .external
            ? effort.estimatedOneRM.map { "\(Goal.trim($0)) kg" } ?? "—"
            : "\(effort.reps) reps"
    }
}
