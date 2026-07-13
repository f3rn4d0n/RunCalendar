import SwiftUI
import MapKit
import CoreLocation

/// Búsqueda de lugares con MapKit. Usa `MKLocalSearch` en lenguaje natural (lo mismo
/// que Apple Maps: encuentra direcciones con número que el autocompletado se salta) y
/// entrega una `RaceLocation` con nombre, dirección y **coordenadas exactas**.
@MainActor
@Observable
final class PlaceSearchModel {

    var query = "" { didSet { scheduleSearch() } }
    private(set) var places: [MKMapItem] = []
    private(set) var isSearching = false

    private var searchTask: Task<Void, Never>?

    /// Si la búsqueda son coordenadas "lat, long", las devuelve.
    var parsedCoordinate: CLLocationCoordinate2D? {
        let numbers = query
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .compactMap { Double($0) }
        guard numbers.count == 2,
              (-90...90).contains(numbers[0]), (-180...180).contains(numbers[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: numbers[0], longitude: numbers[1])
    }

    /// Lanza una búsqueda por texto con debounce (evita una consulta por cada tecla).
    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard text.count >= 3, parsedCoordinate == nil else {
            places = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            let response = try? await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            places = response?.mapItems ?? []
            isSearching = false
        }
    }

    /// Ubicación a partir de un resultado de búsqueda.
    func location(from item: MKMapItem) -> RaceLocation {
        let placemark = item.placemark
        let address = [placemark.thoroughfare, placemark.subThoroughfare, placemark.locality,
                       placemark.administrativeArea, placemark.postalCode]
            .compactMap { $0 }.joined(separator: ", ")
        return RaceLocation(
            name: item.name ?? address,
            address: address,
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }

    /// Convierte coordenadas sueltas en una ubicación, con nombre por reverse-geocoding.
    func location(from coordinate: CLLocationCoordinate2D) async -> RaceLocation {
        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            .first
        let coords = "\(coordinate.latitude), \(coordinate.longitude)"
        let address = [placemark?.locality, placemark?.administrativeArea, placemark?.country]
            .compactMap { $0 }.joined(separator: ", ")
        return RaceLocation(
            name: placemark?.name ?? coords,
            address: address.isEmpty ? coords : address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

/// Fila de un formulario que muestra la ubicación elegida y abre el buscador al tocar.
struct LocationPickerField: View {
    @Binding var location: RaceLocation
    var prompt = "Buscar lugar"

    @State private var searching = false

    var body: some View {
        Button { searching = true } label: {
            HStack {
                if location.name.isEmpty {
                    Label(prompt, systemImage: "magnifyingglass").foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name).foregroundStyle(.primary)
                        if !location.address.isEmpty {
                            Text(location.address).font(.mCaption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: location.latitude != nil ? "mappin.circle.fill" : "chevron.right")
                    .foregroundStyle(location.latitude != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
        }
        .sheet(isPresented: $searching) {
            // Arranca la búsqueda con lo escrito antes (dirección, o nombre si no hay).
            PlaceSearchView(initialQuery: location.address.isEmpty ? location.name : location.address) { resolved in
                location = resolved
                searching = false
            }
        }
    }
}

/// Hoja de búsqueda de lugares (texto/dirección o coordenadas).
private struct PlaceSearchView: View {
    var initialQuery = ""
    let onSelect: (RaceLocation) -> Void

    @State private var model = PlaceSearchModel()
    @State private var didSeed = false
    @State private var pending: PendingPlace?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let coordinate = model.parsedCoordinate {
                    Button {
                        Task { pending = PendingPlace(location: await model.location(from: coordinate)) }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ver estas coordenadas en el mapa")
                                Text("\(coordinate.latitude), \(coordinate.longitude)")
                                    .font(.mCaption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "location.magnifyingglass").foregroundStyle(.tint)
                        }
                    }
                }
                ForEach(model.places, id: \.self) { item in
                    Button {
                        pending = PendingPlace(location: model.location(from: item))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Lugar").foregroundStyle(.primary)
                            if let subtitle = item.placemark.title, !subtitle.isEmpty {
                                Text(subtitle).font(.mCaption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationDestination(item: $pending) { place in
                PlaceConfirmView(location: place.location, onConfirm: onSelect)
            }
            .overlay {
                if model.query.isEmpty {
                    ContentUnavailableView("Busca un lugar",
                                           systemImage: "mappin.and.ellipse",
                                           description: Text("Escribe el nombre, la dirección o unas coordenadas (lat, long)."))
                } else if model.places.isEmpty && model.parsedCoordinate == nil && !model.isSearching {
                    ContentUnavailableView.search(text: model.query)
                }
            }
            .searchable(text: $model.query, prompt: "Nombre o dirección del lugar")
            .navigationTitle("Buscar lugar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
            .onAppear {
                guard !didSeed else { return }
                didSeed = true
                model.query = initialQuery   // dispara la búsqueda con lo previo
            }
        }
    }
}

/// Envoltura Identifiable para navegar al mapa de confirmación.
private struct PendingPlace: Identifiable, Hashable {
    let id = UUID()
    let location: RaceLocation
    static func == (lhs: PendingPlace, rhs: PendingPlace) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Muestra el lugar elegido en un mapa para confirmar que es la dirección correcta.
private struct PlaceConfirmView: View {
    let location: RaceLocation
    let onConfirm: (RaceLocation) -> Void

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude ?? 0, longitude: location.longitude ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))) {
                Marker(location.name, coordinate: coordinate)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(location.name).font(.mHeadline)
                if !location.address.isEmpty {
                    Text(location.address).font(.mSubheadline).foregroundStyle(.secondary)
                }
                Button("Usar este lugar") { onConfirm(location) }
                    .buttonStyle(NeonButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.bar)
        }
        .navigationTitle("¿Es aquí?")
        .navigationBarTitleDisplayMode(.inline)
    }
}
