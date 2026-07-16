import SwiftUI
import UIKit
import Charts

/// Marca de selección para gráficas de tiempo: una línea vertical en el punto tocado
/// con una tarjeta que muestra su fecha y valor. Reutilizable entre gráficas.
@ChartContentBuilder
func chartSelectionMark(date: Date, title: String, value: String) -> some ChartContent {
    RuleMark(x: .value("Seleccionado", date))
        .foregroundStyle(.secondary.opacity(0.35))
        .annotation(position: .top, spacing: 4,
                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
            // Colores explícitos: si no, el texto hereda el estilo tenue de la línea.
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.mCaption2).foregroundStyle(Color.secondary)
                Text(value).font(.mCaption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Color.primary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(uiColor: .separator)))
            .shadow(radius: 2, y: 1)
        }
}

/// Elemento cuya fecha está más cerca de `date` (para resolver la selección del gesto).
func nearestByDate<T>(_ date: Date?, in items: [T], _ dateKey: KeyPath<T, Date>) -> T? {
    guard let date else { return nil }
    return items.min {
        abs($0[keyPath: dateKey].timeIntervalSince(date)) < abs($1[keyPath: dateKey].timeIntervalSince(date))
    }
}
