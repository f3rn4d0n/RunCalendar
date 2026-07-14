import SwiftUI
import CoreLocation
import UIKit

extension RaceLocation {
    /// Coordenada si el lugar tiene latitud y longitud guardadas.
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// App de navegación soportada. Solo se ofrecen las que están instaladas.
enum MapApp: CaseIterable, Identifiable {
    case apple, google, waze

    var id: Self { self }

    var name: String {
        switch self {
        case .apple:  return "Apple Maps"
        case .google: return "Google Maps"
        case .waze:   return "Waze"
        }
    }

    /// URL para detectar si la app está instalada (`canOpenURL`).
    private var probeURL: URL? {
        switch self {
        case .apple:  return URL(string: "maps://")
        case .google: return URL(string: "comgooglemaps://")
        case .waze:   return URL(string: "waze://")
        }
    }

    var isInstalled: Bool {
        guard let probeURL else { return false }
        return UIApplication.shared.canOpenURL(probeURL)
    }

    /// URL de navegación en coche desde la ubicación actual hacia el destino.
    func directionsURL(to c: CLLocationCoordinate2D) -> URL? {
        switch self {
        case .apple:  return URL(string: "http://maps.apple.com/?daddr=\(c.latitude),\(c.longitude)&dirflg=d")
        case .google: return URL(string: "comgooglemaps://?daddr=\(c.latitude),\(c.longitude)&directionsmode=driving")
        case .waze:   return URL(string: "waze://?ll=\(c.latitude),\(c.longitude)&navigate=yes")
        }
    }
}

/// Botón "Cómo llegar": abre la navegación hacia `coordinate` en la app que elija el
/// usuario. Si solo hay una instalada, la abre directo; si hay varias, muestra un menú.
struct NavigateButton: View {
    let coordinate: CLLocationCoordinate2D
    var label = "Cómo llegar"

    @State private var showChooser = false

    private var apps: [MapApp] { MapApp.allCases.filter(\.isInstalled) }

    var body: some View {
        Button {
            if apps.count <= 1 {
                apps.first.map(open)
            } else {
                showChooser = true
            }
        } label: {
            Label(label, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
        }
        .confirmationDialog("Cómo llegar", isPresented: $showChooser, titleVisibility: .visible) {
            ForEach(apps) { app in
                Button(app.name) { open(app) }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func open(_ app: MapApp) {
        guard let url = app.directionsURL(to: coordinate) else { return }
        UIApplication.shared.open(url)
    }
}
