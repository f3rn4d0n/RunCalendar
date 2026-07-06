import SwiftUI

/// Fila de métrica con un botón de info (ⓘ) opcional que abre una card educativa.
struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    var info: MetricInfo?

    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 6) {
            Label(label, systemImage: icon).foregroundStyle(.secondary)
            if let info {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel("Qué significa \(label)")
                .sheet(isPresented: $showInfo) {
                    MetricInfoCard(label: label, icon: icon, info: info)
                }
            }
            Spacer()
            Text(value)
        }
    }
}

/// Card educativa de una métrica: importancia, valoración del dato y referencias.
private struct MetricInfoCard: View {
    let label: String
    let icon: String
    let info: MetricInfo

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(info.importance)
                        .fixedSize(horizontal: false, vertical: true)

                    if let assessment = info.assessment {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(.tint)
                            Text(assessment)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if !info.reference.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Referencia").font(.mHeadline)
                            ForEach(info.reference, id: \.self) { line in
                                Label { Text(line) } icon: {
                                    Image(systemName: "circle.fill").font(.system(size: 5))
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text("Estimado orientativo. No es consejo médico.")
                        .font(.mCaption)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
            }
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
