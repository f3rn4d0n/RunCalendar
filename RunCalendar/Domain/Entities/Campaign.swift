import Foundation

/// Una misión de la campaña: una victoria pequeña y accionable, con su estado sacado de datos
/// reales (no un checkbox manual).
struct CampaignMission: Identifiable, Equatable, Sendable {
    let title: String        // "Corre 40 km esta semana"
    let detail: String       // "vas 22 km"
    let isDone: Bool
    let systemImage: String

    var id: String { title }
}

/// Campaña: el objetivo principal + las misiones de esta semana que te acercan a él. Es la capa
/// de UX que une Fases 1–3 (ver README): en vez de perseguir un número lejano, persigues victorias
/// pequeñas que sí puedes cerrar hoy.
///
/// **Derivada, no persistida**: se arma de la meta ancla + el plan de la semana + la adherencia +
/// las metas secundarias, que ya viven en la app. No hay colección de Firestore ni CRUD.
/// ponytail: una campaña a la vez, la que sale de tu meta principal. Persistir el modelo solo
/// hace falta si quieres varias campañas simultáneas o misiones escritas a mano.
struct Campaign: Equatable, Sendable {
    let title: String            // "Primer Medio Maratón" / nombre de la carrera objetivo
    let goalHeadline: String     // "21K en 2:00"
    let deadline: Date?
    let missions: [CampaignMission]

    /// Fracción de misiones cumplidas (0–1). El progreso que se siente: victorias cerradas.
    var progress: Double {
        guard !missions.isEmpty else { return 0 }
        return Double(missions.filter(\.isDone).count) / Double(missions.count)
    }

    var doneCount: Int { missions.filter(\.isDone).count }

    /// Semanas completas que faltan para la fecha objetivo. `nil` sin fecha.
    func weeksLeft(from now: Date = Date()) -> Int? {
        guard let deadline else { return nil }
        let days = Calendar.current.dateComponents([.day], from: now, to: deadline).day ?? 0
        return max(0, days) / 7
    }
}

extension Campaign {
    /// Misiones de la semana a partir de la adherencia al plan: volumen y frecuencia.
    /// Son las dos que el plan puede medir sin ambigüedad (cuál sesión fue "la de series"
    /// no se sabe: la sesión registrada no guarda el tipo de trabajo).
    static func planMissions(_ adherence: PlanAdherence) -> [CampaignMission] {
        var missions: [CampaignMission] = []
        if adherence.plannedKm > 0 {
            missions.append(CampaignMission(
                title: "Corre \(Goal.trim(adherence.plannedKm)) km esta semana",
                detail: adherence.completedKm >= adherence.plannedKm
                    ? "hecho: \(Goal.trim(adherence.completedKm)) km"
                    : "vas \(Goal.trim(adherence.completedKm)) km",
                isDone: adherence.completedKm >= adherence.plannedKm,
                systemImage: "road.lanes"
            ))
        }
        if adherence.plannedSessions > 0 {
            missions.append(CampaignMission(
                title: "Completa tus \(adherence.plannedSessions) sesiones",
                detail: "vas \(adherence.completedSessions) de \(adherence.plannedSessions)"
                    + (adherence.completedMinutes > 0 ? " · \(adherence.completedMinutes) min" : ""),
                isDone: adherence.completedSessions >= adherence.plannedSessions,
                systemImage: "checklist"
            ))
        }
        // La calidad es misión aparte del número de sesiones: 4 rodajes fáciles no sustituyen
        // al tempo, y de paso es la misión que **no** hay que sobrecumplir.
        if adherence.plannedHardSessions > 0 {
            let done = adherence.completedHardSessions >= adherence.plannedHardSessions
            missions.append(CampaignMission(
                title: "\(adherence.plannedHardSessions) "
                    + (adherence.plannedHardSessions == 1 ? "sesión" : "sesiones") + " de calidad",
                detail: adherence.completedHardSessions > adherence.plannedHardSessions
                    ? "llevas \(adherence.completedHardSessions): ya es de más"
                    : "vas \(adherence.completedHardSessions) de \(adherence.plannedHardSessions)",
                isDone: done,
                systemImage: "bolt.fill"
            ))
        }
        return missions
    }
}
