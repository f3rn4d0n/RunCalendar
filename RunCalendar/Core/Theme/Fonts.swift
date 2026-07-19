import SwiftUI

extension Font {
    /// Fuente de rótulo Permanent Marker, para branding y títulos destacados.
    /// Escala con Dynamic Type respecto al estilo indicado.
    static func marker(_ size: CGFloat, relativeTo textStyle: TextStyle = .largeTitle) -> Font {
        .custom("PermanentMarker", size: size, relativeTo: textStyle)
    }

    // Tipografía del UI Kit: Permanent Marker se reserva para **títulos grandes** y **números
    // destacados** (estos últimos vía `marker(_:)` explícito, p. ej. el número héroe de una meta).
    // El cuerpo, filas, descripciones y captions usan la **fuente del sistema** (San Francisco),
    // que es limpia y muy cercana a Inter — sin bundlear una fuente extra.
    static var mLargeTitle: Font { marker(30, relativeTo: .largeTitle) }
    static var mTitle3: Font { marker(18, relativeTo: .title3) }
    static var mHeadline: Font { .headline }
    static var mBody: Font { .body }
    static var mCallout: Font { .callout }
    static var mSubheadline: Font { .subheadline }
    static var mFootnote: Font { .footnote }
    static var mCaption: Font { .caption }
    static var mCaption2: Font { .caption2 }
}
