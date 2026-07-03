import SwiftUI

/// Evento unificado para mostrar carreras y entrenamientos en el mismo calendario.
private struct CalendarItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let icon: String
    let marker: CalendarMarker
}

/// Vista de calendario que agrega carreras + entrenamientos por día, con puntos de color
/// para ver de un vistazo qué hay cada día.
struct CalendarView: View {
    @State var racesViewModel: RacesViewModel
    @State var trainingViewModel: TrainingViewModel

    @State private var selectedDate = Date()

    private var allItems: [CalendarItem] {
        let raceItems = racesViewModel.races.map {
            CalendarItem(
                id: "race-\($0.id)",
                date: $0.date,
                title: $0.name,
                subtitle: "\($0.discipline.displayName) · \($0.location.name)",
                icon: "flag.checkered",
                marker: CalendarMarker.forRace($0)
            )
        }
        let trainingItems = trainingViewModel.sessions.map {
            CalendarItem(
                id: "training-\($0.id)",
                date: $0.date,
                title: $0.title,
                subtitle: $0.type.displayName,
                icon: $0.type.systemImage,
                marker: .training
            )
        }
        return (raceItems + trainingItems).sorted { $0.date < $1.date }
    }

    /// Marcas por día (clave normalizada al inicio del día) para el calendario.
    private var markersByDay: [Date: [CalendarMarker]] {
        var dict: [Date: [CalendarMarker]] = [:]
        let calendar = Calendar.current
        for item in allItems {
            dict[calendar.startOfDay(for: item.date), default: []].append(item.marker)
        }
        return dict
    }

    private var itemsForSelectedDay: [CalendarItem] {
        allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthCalendarView(selectedDate: $selectedDate, markersByDay: markersByDay)
                    legend
                    Divider()
                    selectedDaySection
                }
                .padding(.vertical)
            }
            .navigationTitle("Calendario")
        }
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
            spacing: 6
        ) {
            ForEach(CalendarMarker.allCases) { marker in
                HStack(spacing: 6) {
                    Circle().fill(marker.color).frame(width: 8, height: 8)
                    Text(marker.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.mediumString())
                .font(.headline)
                .padding(.horizontal)

            if itemsForSelectedDay.isEmpty {
                Text("Sin carreras ni entrenamientos este día.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(itemsForSelectedDay) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.marker.color)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.headline)
                            Text(item.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.date.formatted(.dateTime.hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
