import Foundation
import Testing
@testable import RunCalendar

@Suite("SubmitFeedbackUseCase")
struct FeedbackTests {

    private let userID = "u1"

    private func feedback(_ text: String, rating: Int = 5) -> Feedback {
        Feedback(text: text, rating: rating, createdAt: Date(),
                 appVersion: "1.0", systemVersion: "iOS 18.0")
    }

    @Test("Guarda el comentario con el texto recortado")
    func submitsTrimmed() async throws {
        let repo = FakeFeedbackRepository()
        let submit = SubmitFeedbackUseCase(repository: repo)

        try await submit(feedback("  hay un bug en el calendario \n", rating: 4), userID: userID)

        #expect(repo.submitted.count == 1)
        #expect(repo.submitted.first?.text == "hay un bug en el calendario")
        #expect(repo.submitted.first?.rating == 4)
    }

    @Test("Texto vacío o en blanco lanza invalidInput y no toca el repo")
    func rejectsEmpty() async {
        let repo = FakeFeedbackRepository()
        let submit = SubmitFeedbackUseCase(repository: repo)

        await #expect(throws: AppError.self) {
            try await submit(feedback("   \n  "), userID: userID)
        }
        #expect(repo.submitted.isEmpty)
    }

    @Test("Un fallo del repositorio se propaga")
    func propagatesFailure() async {
        let repo = FakeFeedbackRepository()
        repo.failure = FakeFailure()
        let submit = SubmitFeedbackUseCase(repository: repo)

        await #expect(throws: FakeFailure.self) {
            try await submit(feedback("todo bien"), userID: userID)
        }
    }
}

@MainActor
@Suite("AppReviewPrompt.isDue")
struct AppReviewPromptTests {

    private let now = Date(timeIntervalSince1970: 1_000_000_000)

    @Test("Toca tras una semana desde el primer arranque")
    func dueAfterAWeek() {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        #expect(AppReviewPrompt.isDue(now: now, firstLaunch: weekAgo, alreadyAsked: false))
    }

    @Test("No toca antes de la semana")
    func notDueBefore() {
        let sixDaysAgo = now.addingTimeInterval(-6 * 86_400)
        #expect(!AppReviewPrompt.isDue(now: now, firstLaunch: sixDaysAgo, alreadyAsked: false))
    }

    @Test("No toca si ya se preguntó, aunque haya pasado la semana")
    func notDueIfAlreadyAsked() {
        let monthAgo = now.addingTimeInterval(-30 * 86_400)
        #expect(!AppReviewPrompt.isDue(now: now, firstLaunch: monthAgo, alreadyAsked: true))
    }

    @Test("No toca sin fecha de primer arranque")
    func notDueWithoutFirstLaunch() {
        #expect(!AppReviewPrompt.isDue(now: now, firstLaunch: nil, alreadyAsked: false))
    }
}
