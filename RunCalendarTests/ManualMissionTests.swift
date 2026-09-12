import Foundation
import Testing
@testable import RunCalendar

/// "Varias campañas" es esto: cada meta lleva sus propias misiones manuales, persistidas en el
/// mismo documento de la meta (`Goal.manualMissions`) — sin repositorio ni colección nuevos.
@Suite("GoalsViewModel · misiones manuales")
@MainActor
struct ManualMissionTests {

    @Test("Agregar una misión la manda al repo dentro de la meta, recortada")
    func addSendsTrimmedMission() async {
        let goal = Goal(type: .weight, targetValue: 70)
        let app = TestApp(goals: [goal])
        await app.start()

        await app.goals.addManualMission("  Dormir 8h toda la semana  \n", to: goal)

        let saved = app.goalRepo.updated.last
        #expect(saved?.manualMissions.count == 1)
        #expect(saved?.manualMissions.first?.title == "Dormir 8h toda la semana")
        #expect(saved?.manualMissions.first?.isDone == false)
    }

    @Test("Una misión vacía o en blanco no se agrega")
    func blankMissionIsIgnored() async {
        let goal = Goal(type: .weight, targetValue: 70)
        let app = TestApp(goals: [goal])
        await app.start()

        await app.goals.addManualMission("   ", to: goal)

        #expect(app.goalRepo.updated.isEmpty)
    }

    @Test("Marcar una misión hecha la deja hecha, sin tocar las demás")
    func toggleFlipsOnlyThatMission() async {
        var goal = Goal(type: .weight, targetValue: 70)
        goal.manualMissions = [
            CampaignMission(id: "a", title: "Dormir bien", detail: "", isDone: false, systemImage: "moon"),
            CampaignMission(id: "b", title: "No azúcar", detail: "", isDone: false, systemImage: "xmark")
        ]
        let app = TestApp(goals: [goal])
        await app.start()

        await app.goals.toggleManualMission(goal.manualMissions[0], in: goal)

        let saved = app.goalRepo.updated.last
        #expect(saved?.manualMissions.first { $0.id == "a" }?.isDone == true)
        #expect(saved?.manualMissions.first { $0.id == "b" }?.isDone == false)
    }

    @Test("Borrar una misión la quita y deja las demás intactas")
    func deleteRemovesOnlyThatMission() async {
        var goal = Goal(type: .weight, targetValue: 70)
        goal.manualMissions = [
            CampaignMission(id: "a", title: "Dormir bien", detail: "", isDone: false, systemImage: "moon"),
            CampaignMission(id: "b", title: "No azúcar", detail: "", isDone: false, systemImage: "xmark")
        ]
        let app = TestApp(goals: [goal])
        await app.start()

        await app.goals.deleteManualMission(goal.manualMissions[0], from: goal)

        let saved = app.goalRepo.updated.last
        #expect(saved?.manualMissions.map(\.id) == ["b"])
    }
}
