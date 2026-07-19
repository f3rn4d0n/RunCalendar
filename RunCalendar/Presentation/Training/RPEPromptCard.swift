import SwiftUI

/// Card discreta que pide calificar el esfuerzo (RPE) de entrenamientos recientes que lo
/// tienen vacío. Se descarta con la ✕ y desaparece sola conforme los vas calificando.
struct RPEPromptCard: View {
    let sessions: [TrainingSession]
    let onRate: (TrainingSession, Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Califica el esfuerzo", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.mHeadline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Descartar")
            }

            Text("\(sessions.count) entrenamiento\(sessions.count == 1 ? "" : "s") sin esfuerzo. "
                + "Calificarlos afina tu carga y recuperación.")
                .font(.mCaption).foregroundStyle(.secondary)

            ForEach(sessions.prefix(3)) { session in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.title).font(.mSubheadline).lineLimit(1)
                        Text(session.date.mediumString()).font(.mCaption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        ForEach(1...10, id: \.self) { level in
                            Button("\(level) · \(Self.label(level))") { onRate(session, level) }
                        }
                    } label: {
                        Label("Esfuerzo", systemImage: "plus.circle")
                            .font(.mCaption.weight(.semibold))
                    }
                }
            }

            if sessions.count > 3 {
                Text("y \(sessions.count - 3) más al calificar estos…")
                    .font(.mCaption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Etiqueta corta del nivel de RPE (misma escala que el formulario).
    static func label(_ level: Int) -> String {
        switch level {
        case 1, 2: return "Muy fácil"
        case 3, 4: return "Fácil"
        case 5, 6: return "Moderado"
        case 7, 8: return "Duro"
        default:   return "Máximo"
        }
    }
}
