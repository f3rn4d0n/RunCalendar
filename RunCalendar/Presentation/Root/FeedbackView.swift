import SwiftUI
import StoreKit

/// Comentarios del usuario: valoración 1–5 + texto libre → Firestore (`feedback/`).
/// Si la valoración es alta (≥ 4), al enviar se pide además la reseña nativa en la App Store.
struct FeedbackView: View {
    @State var viewModel: ProfileViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var rating = 0
    @State private var text = ""
    @State private var isSending = false

    private var canSend: Bool {
        rating > 0 && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Valoración").font(.mSubheadline)
                            Spacer()
                            if rating > 0 {
                                Text(Self.ratingLabel(rating))
                                    .font(.mCaption).foregroundStyle(Neon.accent)
                            }
                        }
                        Picker("Valoración", selection: $rating) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text("Del 1 (mal) al 5 (excelente).")
                }

                Section("Comentario") {
                    TextField("Cuéntanos qué mejorar o qué te gustó", text: $text, axis: .vertical)
                        .lineLimit(4...8)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.mFootnote)
                    }
                }
            }
            .navigationTitle("Enviar comentarios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") { Task { await send() } }.disabled(!canSend)
                }
            }
        }
    }

    private func send() async {
        isSending = true
        viewModel.errorMessage = nil
        let ok = await viewModel.sendFeedback(text: text, rating: rating)
        isSending = false
        guard ok else { return }
        // ponytail: solo el prompt in-app. Con App Store ID se puede añadir un Link a
        // "https://apps.apple.com/app/id<APPID>?action=write-review" para quien quiera escribir reseña.
        if rating >= 4 { requestReview() }
        dismiss()
    }

    private static func ratingLabel(_ value: Int) -> String {
        switch value {
        case 1: return "Mal"
        case 2: return "Regular"
        case 3: return "Bien"
        case 4: return "Muy bien"
        default: return "Excelente"
        }
    }
}
