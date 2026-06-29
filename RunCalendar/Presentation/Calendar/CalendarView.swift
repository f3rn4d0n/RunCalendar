import SwiftUI

/// Evento unificado para mostrar carreras y entrenamientos en el mismo calendario.
private struct CalendarItem: Identifiable {
    enum Kind { case race, training }
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    let icon: String
    let kind: Kind
}

/// Vista de calendario que agrega carreras + entrenamientos por día.
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
                kind: .race
            )
        }
        let trainingItems = trainingViewModel.sessions.map {
            CalendarItem(
                id: "training-\($0.id)",
                date: $0.date,
                title: $0.title,
                subtitle: $0.type.displayName,
                icon: $0.type.systemImage,
                kind: .training
            )
        }
        return (raceItems + trainingItems).sorted { $0.date < $1.date }
    }

    private var itemsForSelectedDay: [CalendarItem] {
        allItems.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("Día", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                Divider()

                if itemsForSelectedDay.isEmpty {
                    EmptyStateView(
                        icon: "calendar",
                        title: "Nada este día",
                        message: "No hay carreras ni entrenamientos el \(selectedDate.mediumString())."
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    List(itemsForSelectedDay) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .foregroundStyle(item.kind == .race ? .orange : .blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.date.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Calendario")
            .task {
                await racesViewModel.start()
            }
            .task {
                await trainingViewModel.start()
            }
        }
    }
}
