import SwiftUI

/// Evento unificado para mostrar carreras y entrenamientos en el mismo calendario.
private struct CalendarItem: Identifiable {
    /// Entidad de origen, para poder navegar a su detalle.
    enum Payload {
        case race(Race)
        case training(TrainingSession)
    }
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let icon: String
    let marker: CalendarMarker
    let payload: Payload
}

/// Vista de calendario que agrega carreras + entrenamientos por día, con puntos de color
/// para ver de un vistazo qué hay cada día.
struct CalendarView: View {
    @State var racesViewModel: RacesViewModel
    @State var trainingViewModel: TrainingViewModel

    @State private var selectedDate = Date()

    private var allItems: [CalendarItem] {
        let raceItems = racesViewModel.races.map { race in
            CalendarItem(
                id: "race-\(race.id)",
                date: race.date,
                title: race.name,
                subtitle: "\(race.discipline.displayName) · \(race.location.name)",
                icon: "flag.checkered",
                marker: CalendarMarker.forRace(race),
                payload: .race(race)
            )
        }
        let trainingItems = trainingViewModel.sessions.map { session in
            CalendarItem(
                id: "training-\(session.id)",
                date: session.date,
                title: session.title,
                subtitle: session.type.displayName,
                icon: session.type.systemImage,
                marker: .training,
                payload: .training(session)
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
                    Text(marker.label).font(.mCaption2).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal)
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.mediumString())
                .font(.mHeadline)
                .padding(.horizontal)

            if itemsForSelectedDay.isEmpty {
                Text("Sin carreras ni entrenamientos este día.")
                    .font(.mSubheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(itemsForSelectedDay) { item in
                    NavigationLink {
                        destination(for: item)
                    } label: {
                        row(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func destination(for item: CalendarItem) -> some View {
        switch item.payload {
        case .race(let race):
            RaceDetailView(initialRace: race, viewModel: racesViewModel, trainingViewModel: trainingViewModel)
        case .training(let session):
            TrainingDetailView(
                initialSession: session,
                viewModel: trainingViewModel,
                racesViewModel: racesViewModel
            )
        }
    }

    private func row(for item: CalendarItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(item.marker.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.mHeadline).foregroundStyle(.primary)
                Text(item.subtitle).font(.mSubheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.date.formatted(.dateTime.hour().minute()))
                .font(.mCaption)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.mCaption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}
