import SwiftUI

extension Font {
    /// Fuente de rótulo Permanent Marker, para branding y títulos destacados.
    /// Escala con Dynamic Type respecto al estilo indicado.
    static func marker(_ size: CGFloat, relativeTo textStyle: TextStyle = .largeTitle) -> Font {
        .custom("PermanentMarker", size: size, relativeTo: textStyle)
    }

    // Equivalentes en Permanent Marker de los estilos semánticos del sistema.
    // Tamaños algo menores que los del sistema porque la fuente es más ancha.
    static var mLargeTitle: Font { marker(30, relativeTo: .largeTitle) }
    static var mTitle3: Font { marker(18, relativeTo: .title3) }
    static var mHeadline: Font { marker(16, relativeTo: .headline) }
    static var mBody: Font { marker(16, relativeTo: .body) }
    static var mCallout: Font { marker(15, relativeTo: .callout) }
    static var mSubheadline: Font { marker(14, relativeTo: .subheadline) }
    static var mFootnote: Font { marker(12, relativeTo: .footnote) }
    static var mCaption: Font { marker(11, relativeTo: .caption) }
    static var mCaption2: Font { marker(10, relativeTo: .caption2) }
}
