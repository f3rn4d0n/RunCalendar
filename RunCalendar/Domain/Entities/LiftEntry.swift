import Foundation

/// Un resultado de levantamiento registrado suelto, sin un WOD detrás — "hoy hice sentadilla a
/// 100×5", nada más. Vive en su propia colección porque, a diferencia de una serie de WOD, no
/// tiene sesión que lo contenga: fecha, ejercicio, peso y reps son todo su contenido.
struct LiftEntry: Identifiable, Equatable, Sendable, LiftPerformance {
    let id: String
    var exercise: StrengthExercise
    var weightKg: Double
    var reps: Int
    var date: Date

    init(
        id: String = UUID().uuidString,
        exercise: StrengthExercise,
        weightKg: Double,
        reps: Int,
        date: Date = Date()
    ) {
        self.id = id
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.date = date
    }
}
