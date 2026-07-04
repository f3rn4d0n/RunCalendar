import SwiftUI

/// Calendario mensual propio: muestra en cada día puntos de color según lo que haya
/// (carreras/entrenamientos) para verlo de un vistazo sin seleccionar el día.
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    /// Marcas por día, con la clave normalizada al inicio del día (`startOfDay`).
    let markersByDay: [Date: [CalendarMarker]]

    @State private var monthAnchor: Date
    private let calendar = Calendar.current

    // Tamaños que escalan con Dynamic Type.
    @ScaledMetric private var daySize: CGFloat = 32
    @ScaledMetric private var dotSize: CGFloat = 5

    init(selectedDate: Binding<Date>, markersByDay: [Date: [CalendarMarker]]) {
        self._selectedDate = selectedDate
        self.markersByDay = markersByDay
        self._monthAnchor = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            grid
        }
    }

    private var header: some View {
        HStack {
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 32)
            }
            .accessibilityLabel("Mes anterior")
            Spacer()
            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(.mHeadline)
            Spacer()
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 32)
            }
            .accessibilityLabel("Mes siguiente")
        }
        .padding(.horizontal)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.mCaption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(minHeight: daySize + 14)
                }
            }
        }
        .padding(.horizontal, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let markers = uniqueMarkers(markersByDay[calendar.startOfDay(for: day)] ?? [])

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.mCallout)
                    .fontWeight(isToday ? .bold : .regular)
                    .frame(width: daySize, height: daySize)
                    .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear), in: Circle())
                    .foregroundStyle(dayForeground(isSelected: isSelected, isToday: isToday))
                dotsRow(markers)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(daySummary(for: day, markers: markers, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func dayForeground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }

    private func dotsRow(_ markers: [CalendarMarker]) -> some View {
        HStack(spacing: 2) {
            ForEach(markers.prefix(4)) { marker in
                Circle().fill(marker.color).frame(width: dotSize, height: dotSize)
            }
        }
        .frame(height: dotSize + 1)
        .accessibilityHidden(true) // el resumen del día ya nombra las marcas
    }

    /// Resumen de accesibilidad del día: fecha + "hoy" + marcas presentes.
    private func daySummary(for day: Date, markers: [CalendarMarker], isToday: Bool) -> String {
        var parts = [day.formatted(.dateTime.day().month(.wide))]
        if isToday { parts.append("hoy") }
        if !markers.isEmpty { parts.append(markers.map(\.label).joined(separator: ", ")) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Cálculo de días

    /// Días a mostrar: celdas vacías (nil) al inicio para alinear el primer día de la semana.
    private var daysInGrid: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstOfMonth = interval.start
        let daysCount = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<daysCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        return cells
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Marcas únicas en el orden canónico de `CalendarMarker.allCases`.
    private func uniqueMarkers(_ markers: [CalendarMarker]) -> [CalendarMarker] {
        CalendarMarker.allCases.filter { markers.contains($0) }
    }

    private func changeMonth(_ delta: Int) {
        if let date = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = date
        }
    }
}
