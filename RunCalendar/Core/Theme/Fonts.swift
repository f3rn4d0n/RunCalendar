import SwiftUI

extension Font {
    /// Fuente de rótulo Permanent Marker, para branding y títulos destacados.
    /// Escala con Dynamic Type respecto al estilo indicado.
    static func marker(_ size: CGFloat, relativeTo textStyle: TextStyle = .largeTitle) -> Font {
        .custom("PermanentMarker", size: size, relativeTo: textStyle)
    }
}
