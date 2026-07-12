import SwiftUI
import MapKit

/// Mapa interactivo de la traza GPS de una corrida: dibuja la ruta coloreada por
/// zona de FC y anima un marcador que reproduce el recorrido mostrando velocidad,
/// ritmo, BPM y zona en cada momento. Los datos salen de Apple Salud (Apple Watch).
struct WorkoutRouteMapView: View {
    let title: String
    let date: Date
    let distanceKm: Double?
    /// Cargador inyectado (usa el TrainingViewModel, que ya conoce Salud).
    let loader: (Date, Double?) async -> WorkoutRoute?
    let isAvailable: Bool

    @State private var route: WorkoutRoute?
    @State private var isLoading = true
    @State private var index = 0
    @State private var isPlaying = false
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if !isAvailable {
                EmptyStateView(
                    icon: "map",
                    title: "No disponible aquí",
                    message: "La ruta con GPS de Apple Salud está disponible en tu iPhone."
                )
            } else if isLoading {
                ProgressView("Buscando tu ruta en Salud…")
            } else if let route, !route.isEmpty {
                content(route)
            } else {
                EmptyStateView(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    title: "Sin ruta GPS",
                    message: "Esta corrida no tiene una ruta GPS guardada en Salud. Suele pasar con "
                        + "corridas en caminadora o registradas por otra app (Nike, Strava…), que "
                        + "guardan la distancia pero no la traza. Las corridas al aire libre con "
                        + "Apple Watch sí la incluyen."
                )
            }
        }
        .navigationTitle("Ruta")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard isAvailable else { isLoading = false; return }
            route = await loader(date, distanceKm)
            camera = route.map { .region(Self.region(for: $0.points)) } ?? .automatic
            isLoading = false
        }
    }

    private func content(_ route: WorkoutRoute) -> some View {
        VStack(spacing: 0) {
            map(route)
            controls(route)
        }
    }

    // MARK: - Mapa

    private func map(_ route: WorkoutRoute) -> some View {
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            // Ruta coloreada por tramos de misma zona de FC (o color de acento si no hay FC).
            ForEach(segments(route.points)) { seg in
                MapPolyline(coordinates: seg.coordinates)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            // Marcador que reproduce el recorrido.
            Annotation("", coordinate: current(route).coordinate) {
                ZStack {
                    Circle().fill(.background).frame(width: 22, height: 22)
                    Circle().fill(current(route).zone.map(color(for:)) ?? Neon.accent)
                        .frame(width: 14, height: 14)
                }
                .shadow(radius: 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controles + lectura de métricas

    private func controls(_ route: WorkoutRoute) -> some View {
        let point = current(route)
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                metric("Velocidad", "\(point.speedKmh.formatted(.number.precision(.fractionLength(1)))) km/h",
                       icon: "speedometer", tint: Neon.accent)
                metric("Ritmo", pace(point.speedKmh), icon: "stopwatch", tint: Neon.teal)
                metric("FC", point.heartRate.map { "\($0) bpm" } ?? "—",
                       icon: "heart.fill", tint: point.zone.map(color(for:)) ?? Neon.orange)
            }

            HStack {
                Label("\(point.distanceKm.formatted(.number.precision(.fractionLength(2)))) km",
                      systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.mSubheadline.weight(.semibold))
                Spacer()
                Text("+\(Int(point.elapsed))s").font(.mCaption).foregroundStyle(.secondary)
            }

            if let zone = point.zone {
                HStack {
                    Circle().fill(color(for: zone)).frame(width: 10, height: 10)
                    Text("\(zone.label) · \(zone.percentRange) de FC máx")
                        .font(.mCaption).foregroundStyle(.secondary)
                    Spacer()
                }
            }

            HStack(spacing: 14) {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Neon.accent)
                }
                .accessibilityLabel(isPlaying ? "Pausar" : "Reproducir recorrido")

                Slider(
                    value: Binding(
                        get: { Double(index) },
                        set: { index = Int($0); isPlaying = false }
                    ),
                    in: 0...Double(max(route.points.count - 1, 1))
                )
            }
        }
        .padding()
        .background(.bar)
        .task(id: isPlaying) { await play(route) }
    }

    private func metric(_ label: String, _ value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.mHeadline).monospacedDigit()
            Text(label).font(.mCaption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reproducción

    /// Avanza el marcador a lo largo de la ruta mientras `isPlaying`.
    /// Índice directo (sin `withAnimation`): igual que el scrubber. Animar la
    /// coordenada haría que MapKit interpole el pin entre puntos y se salga de la ruta.
    private func play(_ route: WorkoutRoute) async {
        guard isPlaying else { return }
        if index >= route.points.count - 1 { index = 0 } // reiniciar si estaba al final
        // Traza completa en ~12 s, sin importar cuántos puntos tenga.
        let stepNanos = UInt64(12_000_000_000 / UInt64(max(route.points.count, 1)))
        while isPlaying && index < route.points.count - 1 {
            try? await Task.sleep(nanoseconds: stepNanos)
            if !isPlaying { break }
            index += 1
        }
        isPlaying = false
    }

    // MARK: - Helpers

    private func current(_ route: WorkoutRoute) -> RoutePoint {
        route.points[min(index, route.points.count - 1)]
    }

    /// Ritmo min/km a partir de la velocidad (— si está detenido).
    private func pace(_ speedKmh: Double) -> String {
        guard speedKmh > 0.5 else { return "—" }
        let secPerKm = 3600 / speedKmh
        return "\(Int(secPerKm) / 60):\(String(format: "%02d", Int(secPerKm) % 60)) /km"
    }

    private func color(for zone: HeartRateZone) -> Color {
        switch zone {
        case .z1: return Neon.teal
        case .z2: return Neon.green
        case .z3: return Neon.gold
        case .z4: return Neon.orange
        case .z5: return Color(red: 1.0, green: 0.23, blue: 0.42)
        }
    }

    /// Región que encuadra toda la ruta con un margen.
    private static func region(for points: [RoutePoint]) -> MKCoordinateRegion {
        let lats = points.map(\.latitude), lons = points.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion(.world)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4 + 0.002,
            longitudeDelta: (maxLon - minLon) * 1.4 + 0.002
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    /// Agrupa puntos consecutivos de la misma zona en tramos coloreables.
    private func segments(_ points: [RoutePoint]) -> [RouteSegment] {
        var result: [RouteSegment] = []
        var currentZone: HeartRateZone?
        var buffer: [CLLocationCoordinate2D] = []

        func flush() {
            guard buffer.count >= 2 else { buffer = []; return }
            result.append(RouteSegment(
                id: result.count,
                color: currentZone.map(color(for:)) ?? Neon.accent,
                coordinates: buffer
            ))
        }

        for point in points {
            let coord = point.coordinate
            if point.zone == currentZone {
                buffer.append(coord)
            } else {
                buffer.append(coord)   // solapa un punto para que los tramos se unan sin huecos
                flush()
                currentZone = point.zone
                buffer = [coord]
            }
        }
        flush()
        return result
    }
}

private struct RouteSegment: Identifiable {
    let id: Int
    let color: Color
    let coordinates: [CLLocationCoordinate2D]
}

private extension RoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
