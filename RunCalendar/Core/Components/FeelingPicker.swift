import SwiftUI

/// Selector de "¿cómo te sientes hoy?" (1–5).
///
/// Vive fuera de *Progreso* porque se usa en dos sitios: la sección de check-in y, sobre todo,
/// pegado al anillo de recuperación en *Hoy* — que es la pantalla que se abre a diario. Al fondo de
/// *Progreso* no lo veía nadie, y navegar a otra pantalla para pulsar uno de cinco botones es más
/// fricción que el propio registro.
struct FeelingPicker: View {
    let selected: Int?
    let onPick: (Int) async -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    Task { await onPick(value) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "\(value).circle.fill").font(.system(size: 26))
                            .foregroundStyle(Self.color(value))
                        Text(Self.label(value)).font(.mCaption2).lineLimit(1)
                            .foregroundStyle(selected == value ? AnyShapeStyle(Self.color(value))
                                                               : AnyShapeStyle(.secondary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selected == value ? AnyShapeStyle(Self.color(value).opacity(0.16))
                                                  : AnyShapeStyle(Color.clear),
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    static func label(_ value: Int) -> String {
        switch value {
        case 1: return "Agotado"
        case 2: return "Cansado"
        case 3: return "Normal"
        case 4: return "Bien"
        default: return "Fresco"
        }
    }

    /// Color por nivel de cansancio: rojo (agotado) → verde (fresco).
    static func color(_ value: Int) -> Color {
        switch value {
        case 1: return Color(red: 0.90, green: 0.25, blue: 0.30)
        case 2: return Neon.orange
        case 3: return Neon.gold
        case 4: return Neon.teal
        default: return Neon.green
        }
    }
}
