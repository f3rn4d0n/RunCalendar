import SwiftUI
import AuthenticationServices

/// Pantalla de inicio de sesión: email/contraseña + Sign in with Apple.
struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 14) {
                        TextField("Correo", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Contraseña", text: $password)
                            .textContentType(.password)
                    }
                    .textFieldStyle(.roundedBorder)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await viewModel.signInWithEmail(email: email, password: password) }
                    } label: {
                        Text("Entrar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isProcessing)

                    Button("¿No tienes cuenta? Regístrate") { showSignUp = true }
                        .font(.footnote)

                    HStack { Divider(); Text("o").foregroundStyle(.secondary); Divider() }

                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleCompletion(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    // El botón fija su estilo al crearse y no reacciona al cambio de
                    // modo en caliente; el id fuerza a SwiftUI a recrearlo al cambiar.
                    .id(colorScheme)

                    GoogleSignInButton {
                        Task { await viewModel.continueWithGoogle() }
                    }
                    .disabled(viewModel.isProcessing)

                    if viewModel.isProcessing { ProgressView() }
                }
                .padding(24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("RunCalendar")
            .sheet(isPresented: $showSignUp) {
                SignUpView(viewModel: viewModel)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Tu calendario de carreras y entrenamientos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }
}
