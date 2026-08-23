import SwiftUI

struct LoginView: View {
    @ObservedObject var authRepository = AuthRepository.shared
    @Binding var isLoggedIn: Bool

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "banknote.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)

            Text("FinancePY")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Gestión financiera personal")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if isLoading {
                ProgressView("Iniciando sesión...")
                    .padding()
            } else {
                Button(action: performLogin) {
                    Text("Iniciar sesión")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }

    private func performLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authRepository.login()
                isLoggedIn = true
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
