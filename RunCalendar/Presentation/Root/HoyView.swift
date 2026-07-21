import SwiftUI

/// "Hoy": el dashboard de arranque del atleta. Responde de un vistazo: ¿qué carrera viene?,
/// ¿qué entreno toca hoy?, ¿cómo va mi recuperación? Y da acceso a Carreras y Calendario.
struct HoyView: View {
    let racesViewModel: RacesViewModel
    let trainingViewModel: TrainingViewModel
    let healthViewModel: HealthViewModel
    @State var goalsViewModel: GoalsViewModel
    // Perfil (se abre desde el avatar).
    let user: AppUser
    let authViewModel: AuthViewModel
    let profileViewModel: ProfileViewModel
    let remindersViewModel: RemindersViewModel

    @State private var showProfile = false
    @State private var showWeightSheet = false
    @State private var showReviewSheet = false
    @State private var showPlanConfig = false

    private var nextRace: Race? {
        let today = Calendar.current.startOfDay(for: Date())
        return racesViewModel.races
            .filter { $0.status == .upcoming && $0.date >= today }
            .min { $0.date < $1.date }
    }

    private var todaySession: TrainingSession? {
        trainingViewModel.sessions.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    reviewPromptCard
                    weightPromptCard
                    nextRaceCard
                    missionCard
                    todayTrainingCard
                    recoveryCard
                    accessLinks
                }
                .padding(16)
            }
            .background(Neon.background.ignoresSafeArea())
            .navigationTitle("Hoy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.crop.circle").font(.title2)
                    }
                    .accessibilityLabel("Perfil")
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(user: user, authViewModel: authViewModel,
                            viewModel: profileViewModel, remindersViewModel: remindersViewModel,
                            goalsViewModel: goalsViewModel)
            }
            .sheet(isPresented: $showWeightSheet) {
                MeasureEntrySheet(viewModel: goalsViewModel, measure: .weight)
            }
            .sheet(isPresented: $showReviewSheet) {
                WeeklyReviewView(viewModel: goalsViewModel)
            }
            .sheet(isPresented: $showPlanConfig) {
                PlanConfigSheet(viewModel: goalsViewModel)
            }
        }
    }

    /// Misión del día (Fase 3): la sesión que el plan te pide hoy, derivada de tus objetivos.
    @ViewBuilder private var missionCard: some View {
        DashCard(eyebrow: "Misión de hoy", accent: Neon.green) {
            if let mission = goalsViewModel.todayMission {
                HStack(spacing: 12) {
                    Image(systemName: mission.kind.systemImage)
                        .font(.title2).foregroundStyle(Neon.green).frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.label).font(.mHeadline).foregroundStyle(.primary)
                        Text(mission.detail).font(.mCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                planFooter
            } else if goalsViewModel.currentPlan != nil {
                Text("Hoy descansas. La recuperación también entrena.")
                    .font(.mSubheadline).foregroundStyle(.secondary)
                planFooter
            } else {
                Text("Crea una meta de carrera en Objetivos y te armo un plan semanal automático.")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
    }

    /// Aviso del coach (si el volumen no cabe en los días dados) + acceso a ajustar la config.
    @ViewBuilder private var planFooter: some View {
        if let note = goalsViewModel.currentPlan?.note {
            Label(note, systemImage: "exclamationmark.triangle.fill")
                .font(.mCaption2).foregroundStyle(Neon.orange)
        }
        Button { showPlanConfig = true } label: {
            Label("\(goalsViewModel.planConfig.daysPerWeek) días/semana · ajustar",
                  systemImage: "slider.horizontal.3")
                .font(.mCaption).foregroundStyle(Neon.accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cards

    /// Review dominical (Fase 2): solo aparece los domingos y si aún no lo hiciste esta semana.
    @ViewBuilder private var reviewPromptCard: some View {
        if goalsViewModel.needsWeeklyReview {
            DashCard(eyebrow: "Review de la semana", accent: Neon.purple) {
                HStack(alignment: .top) {
                    Text("Domingo de balance: peso, cintura, energía y hambre. Cinco campos que explican cómo fue tu semana.")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                    Button {
                        goalsViewModel.reviewPromptDismissedOn = Date()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Descartar")
                }
                Button("Hacer review") { showReviewSheet = true }
                    .buttonStyle(NeonButtonStyle())
            }
        }
    }

    /// Pide el peso solo si tienes una meta de peso y toca registrarlo (cada 2 días).
    /// Al guardar desaparece sola: el último registro pasa a ser de hoy.
    @ViewBuilder private var weightPromptCard: some View {
        if goalsViewModel.needsWeightLog {
            DashCard(eyebrow: "Registra tu peso", accent: Neon.gold) {
                HStack(alignment: .top) {
                    Text(goalsViewModel.latestWeight.map { (entry: MeasurementEntry) -> String in
                        "Tu último registro fue el \(entry.date.mediumString()) (\(Goal.trim(entry.value)) kg). Pésate para ver cómo va tu meta."
                    } ?? "Aún no registras tu peso. El primero marca tu punto de partida.")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                    Button {
                        goalsViewModel.weightPromptDismissedOn = Date()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Descartar")
                }
                Button("Registrar peso") { showWeightSheet = true }
                    .buttonStyle(NeonButtonStyle())
            }
        }
    }

    @ViewBuilder private var nextRaceCard: some View {
        if let race = nextRace {
            NavigationLink {
                RaceDetailView(initialRace: race, viewModel: racesViewModel,
                               trainingViewModel: trainingViewModel, healthViewModel: healthViewModel)
            } label: {
                DashCard(eyebrow: "Próxima carrera", accent: Neon.teal) {
                    Text(race.name).font(.mHeadline).foregroundStyle(.primary)
                    Text(race.date.countdownText()).font(.marker(26)).foregroundStyle(Neon.teal)
                    Text("\(race.discipline.displayName) · \(race.location.name)")
                        .font(.mCaption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                RaceListView(viewModel: racesViewModel, trainingViewModel: trainingViewModel,
                             healthViewModel: healthViewModel)
            } label: {
                DashCard(eyebrow: "Carreras", accent: Neon.teal) {
                    Text("Sin carreras próximas. Agrega tu próxima meta.")
                        .font(.mSubheadline).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var todayTrainingCard: some View {
        DashCard(eyebrow: "Hoy entrenas", accent: Neon.purple) {
            if let session = todaySession {
                NavigationLink {
                    TrainingDetailView(initialSession: session, viewModel: trainingViewModel,
                                       racesViewModel: racesViewModel)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(.mHeadline).foregroundStyle(.primary)
                            Text(session.type.displayName).font(.mCaption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: session.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(session.completed ? Neon.green : .secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("Descanso hoy. Aprovecha para recuperar.")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var recoveryCard: some View {
        DashCard(eyebrow: "Recuperación", accent: healthViewModel.recovery.map { recoveryColor($0.level) } ?? Neon.accent) {
            if let r = healthViewModel.recovery {
                HStack(spacing: 14) {
                    ProgressRing(progress: recoveryFraction(r.level), color: recoveryColor(r.level),
                                 lineWidth: 6, size: 58) {
                        Text(r.remainingHours > 0 ? r.remainingText.replacingOccurrences(of: "~", with: "") : "Listo")
                            .font(.marker(13)).foregroundStyle(recoveryColor(r.level))
                            .lineLimit(1).minimumScaleFactor(0.5).frame(width: 40)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.level.rawValue).font(.mHeadline)
                        Text(r.remainingHours > 0 ? "para estar listo" : "Listo para entrenar")
                            .font(.mCaption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else if healthViewModel.isLoading {
                recoverySkeleton
            } else {
                Text("Conecta Apple Salud en Progreso para ver tu recuperación.")
                    .font(.mSubheadline).foregroundStyle(.secondary)
            }
        }
    }

    /// Skeleton mientras carga la condición: misma silueta que la card real, atenuada.
    private var recoverySkeleton: some View {
        HStack(spacing: 14) {
            Circle().fill(Color.primary.opacity(0.08)).frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recuperado").font(.mHeadline)
                Text("para estar listo").font(.mCaption).foregroundStyle(.secondary)
            }
            .redacted(reason: .placeholder)
            Spacer()
        }
        .shimmering()
    }

    private var accessLinks: some View {
        VStack(spacing: 10) {
            NavigationLink {
                RaceListView(viewModel: racesViewModel, trainingViewModel: trainingViewModel,
                             healthViewModel: healthViewModel)
            } label: { DashLink(title: "Todas las carreras", icon: "flag.checkered") }
                .buttonStyle(.plain)
            NavigationLink {
                CalendarView(racesViewModel: racesViewModel, trainingViewModel: trainingViewModel,
                             healthViewModel: healthViewModel)
            } label: { DashLink(title: "Calendario", icon: "calendar") }
                .buttonStyle(.plain)
        }
    }

    // MARK: - Recovery helpers (mismo criterio que Progreso)

    private func recoveryColor(_ level: RecoveryLevel) -> Color {
        switch level {
        case .recovered: return Neon.green
        case .partial:   return Neon.gold
        case .fatigued:  return Neon.orange
        }
    }

    private func recoveryFraction(_ level: RecoveryLevel) -> Double {
        switch level {
        case .recovered: return 1.0
        case .partial:   return 0.6
        case .fatigued:  return 0.3
        }
    }
}

/// Card del dashboard: rótulo de acento + contenido, sobre superficie del Kit.
struct DashCard<Content: View>: View {
    let eyebrow: String
    var accent: Color = Neon.accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(eyebrow.uppercased()).font(.mCaption2).tracking(1).foregroundStyle(accent)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Neon.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.06)))
    }
}

/// Fila de acceso rápido (ícono + título + chevron).
struct DashLink: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Neon.accent).frame(width: 24)
            Text(title).font(.mHeadline).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.mCaption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14).padding(.horizontal, 16)
        .background(Neon.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
    }
}
