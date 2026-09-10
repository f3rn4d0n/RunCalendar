import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {

    private(set) var profile = UserProfile()
    var errorMessage: String?
    private var hasStarted = false

    let userID: String
    private let observeProfile: ObserveProfileUseCase
    private let saveProfile: SaveProfileUseCase
    private let submitFeedback: SubmitFeedbackUseCase

    init(
        userID: String,
        observeProfile: ObserveProfileUseCase,
        saveProfile: SaveProfileUseCase,
        submitFeedback: SubmitFeedbackUseCase
    ) {
        self.userID = userID
        self.observeProfile = observeProfile
        self.saveProfile = saveProfile
        self.submitFeedback = submitFeedback
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for await remote in observeProfile(userID: userID) {
            if let remote { profile = remote }
        }
    }

    func save(_ profile: UserProfile) async -> Bool {
        do {
            try await saveProfile(profile, userID: userID)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Manda un comentario a Firestore. Devuelve `true` si se guardó (la vista cierra el sheet
    /// y, si `rating >= 4`, pide la valoración en la App Store).
    func sendFeedback(text: String, rating: Int) async -> Bool {
        let feedback = Feedback(
            text: text,
            rating: rating,
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
        do {
            try await submitFeedback(feedback, userID: userID)
            Haptics.success()
            Usage.feedbackSent(rating: rating)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
