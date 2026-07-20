import SwiftUI

/// Pantalla de inicio de sesión: email/contraseña + Sign in with Apple.
struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

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
                        PasswordField("Contraseña", text: $password)
                    }
                    .textFieldStyle(.roundedBorder)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.mFootnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await viewModel.signInWithEmail(email: email, password: password) }
                    } label: {
                        Text("Entrar")
                    }
                    .buttonStyle(NeonButtonStyle())
                    .disabled(viewModel.isProcessing)

                    Button("¿No tienes cuenta? Regístrate") { showSignUp = true }
                        .font(.mFootnote)

                    HStack { Divider(); Text("o continúa con").foregroundStyle(.secondary); Divider() }

                    HStack(spacing: 20) {
                        AppleIconButton { viewModel.startSignInWithApple() }
                        GoogleSignInButton { Task { await viewModel.continueWithGoogle() } }
                    }
                    .disabled(viewModel.isProcessing)

                    if viewModel.isProcessing { ProgressView() }
                }
                .padding(24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSignUp) {
                SignUpView(viewModel: viewModel)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Neon.logoGradient)
                .shadow(color: Neon.accent.opacity(0.5), radius: 12)
            Text("Rumbo")
                .font(.marker(40))
                .foregroundStyle(Neon.logoGradient)
                .shadow(color: Neon.accent.opacity(0.4), radius: 8)
            Text("Tu calendario de carreras y entrenamientos")
                .font(.mSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }
}
