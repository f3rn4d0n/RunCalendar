import SwiftUI
import UIKit

/// Campo de contraseña con botón de ojo para alternar entre mostrar y ocultar el texto.
struct PasswordField: View {
    private let title: String
    @Binding private var text: String
    private let textContentType: UITextContentType?

    @State private var isVisible = false
    @FocusState private var isFocused: Bool

    init(_ title: String, text: Binding<String>, textContentType: UITextContentType? = .password) {
        self.title = title
        self._text = text
        self.textContentType = textContentType
    }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isVisible {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)

            Button {
                isVisible.toggle()
                isFocused = true // conserva el foco al alternar
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Ocultar contraseña" : "Mostrar contraseña")
        }
    }
}
