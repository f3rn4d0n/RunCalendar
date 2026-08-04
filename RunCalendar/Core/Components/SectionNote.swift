import SwiftUI

/// Nota explicativa **dentro** de su sección, en vez de en el `footer`.
///
/// iOS pone estas notas debajo de la sección, y ahí el problema es que el footer de un bloque y el
/// header del siguiente se leen con el mismo peso y quedan pegados: no se distingue de quién habla
/// el texto. En una pantalla con muchas secciones seguidas —*Progreso*— eso se percibe como
/// desorden aunque cada bloque esté bien.
///
/// Metida dentro, la pertenencia es inequívoca. Se paga desviarse de la convención de la
/// plataforma, así que conserva lo que el footer sí hacía bien: tipografía pequeña, color
/// secundario y sin separador, para que se lea como nota y no como una fila más de datos.
///
/// Ver *criterio 4: un tema, un bloque* en `docs/ux-jerarquia.md`.
struct SectionNote<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.mCaption)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 2)
    }
}

extension SectionNote where Content == Text {
    init(_ text: String) { self.init { Text(text) } }
}
