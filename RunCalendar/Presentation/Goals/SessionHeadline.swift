import SwiftUI

/// Encabezado compacto de una sesión. En **series**, el kilometraje es solo la parte *fuerte*, así
/// que lo resaltamos en color y añadimos en pequeño el calentamiento/enfriamiento — para que no se
/// lea como el total de la sesión. Los demás tipos usan su etiqueta directa.
struct SessionHeadline: View {
    let day: PlannedDay

    var body: some View {
        if day.kind == .intervals {
            Text("10 min cal. + ").font(.mCaption2).foregroundStyle(.secondary)
            + Text("\(Goal.trim(day.targetKm ?? 0)) km fuerte")
                .font(.mSubheadline).foregroundStyle(Neon.orange)
            + Text(" + 10 min enf.").font(.mCaption2).foregroundStyle(.secondary)
        } else {
            Text(day.label).font(.mSubheadline).foregroundStyle(.primary)
        }
    }
}
