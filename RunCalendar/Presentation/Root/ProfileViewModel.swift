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

    init(
        userID: String,
        observeProfile: ObserveProfileUseCase,
        saveProfile: SaveProfileUseCase
    ) {
        self.userID = userID
        self.observeProfile = observeProfile
        self.saveProfile = saveProfile
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
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
