import SwiftUI

/// Registro con email y contraseña.
struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool { !password.isEmpty && password == confirmPassword }

    var body: some View {
        NavigationStack {
            Form {
                Section("Crear cuenta") {
                    TextField("Correo", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PasswordField("Contraseña (mín. 6)", text: $password, textContentType: .newPassword)
                    PasswordField("Confirmar contraseña", text: $confirmPassword, textContentType: .newPassword)
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }

                Section {
                    Button {
                        Task {
                            await viewModel.register(email: email, password: password)
                            if viewModel.errorMessage == nil { dismiss() }
                        }
                    } label: {
                        if viewModel.isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Registrarme")
                        }
                    }
                    .buttonStyle(NeonButtonStyle())
                    .disabled(!passwordsMatch || viewModel.isProcessing)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Registro")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
