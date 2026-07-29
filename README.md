# Rumbo 🏃‍♂️

> **Nombre:** la app se llama **Rumbo** (nombre de display, `CFBundleDisplayName`). El **repo, el target
> Xcode, el scheme, el bundle id** (`com.fercho.runcalendar.app`) y **Firebase** siguen como *RunCalendar*
> a propósito — el rename técnico es riesgoso (migrar Firebase) y no urgente (no publicado). Compila con
> `-scheme RunCalendar`. No cambies esos identificadores sin migrar Firebase.

App iPhone/Mac que es un **coach del atleta híbrido**: tus **objetivos** (con sugerencia y ritmo
esperado), tu **entrenamiento** (carrera, CrossFit, caminata, senderismo — con import de Apple Salud,
rutas y RPE), tu **progreso/condición** (recuperación, calibración, ACWR, VO₂max, readiness) y tu
agenda de **carreras**. Navegación por *ciclo del atleta*: **Hoy · Entrenar · Objetivos · Progreso**.

Construida con **SwiftUI**, **Clean Architecture**, **SOLID** y **Firebase** (Auth + Firestore).

> **¿Eres otra IA o dev retomando el proyecto?** Empieza por [Funcionalidades](#funcionalidades)
> (qué existe hoy) y el [Mapa del código](#mapa-del-código-para-retomar-rápido) (dónde vive qué +
> cableado de ViewModels), luego [Notas para desarrolladores](#notas-para-desarrolladores--ia)
> (convenciones y trampas) y [Troubleshooting](#troubleshooting). El [Roadmap](#roadmap-y-backlog)
> tiene la visión; [Pendientes](docs/pendientes.md) tiene el backlog priorizado.

---

## Funcionalidades

**Cuatro pestañas por *ciclo del atleta*** (las 4 preguntas de la mañana): **Hoy** · **Entrenar** ·
**Objetivos** · **Progreso**. **Carreras** y **Calendario** se abren desde *Hoy*; **Perfil** es el
avatar de la barra superior. (Antes eran 6 tabs por tipo de dato → iOS las colapsaba en "More".)

### ☀️ Hoy
- Dashboard de arranque: **próxima carrera** (countdown; la próxima **inscrita o prioritaria**, no
  la primera del calendario — las que solo estás considerando no tapan a la de verdad) ·
  **misión de hoy** (la sesión que el plan te pide) · **entreno de hoy** (lo que registraste, todos
  los del día si entrenaste más de una vez) · **recuperación** (ring). Accesos a *Todas las
  carreras* y *Calendario*. Avatar → Perfil. Es la pantalla que responde "¿qué hago hoy?".
- **Misión de hoy** (Fase 3): la sesión planificada de hoy, derivada de tus objetivos + tu volumen
  real. Se toca para ver el **detalle** (qué/cómo/para qué/por qué). Ver [Plan](#-plan-fase-3).

### 🗓️ Plan (Fase 3)
- **Generación automática de entrenamientos** desde tus objetivos, **determinista** (sin IA, como
  "Sugerir meta"). El plan **no se persiste**: es una función pura de metas + volumen de carrera +
  config, se recalcula reactivo. Solo la **config** (días/semana + días preferidos) se guarda
  (UserDefaults). Vive en `GoalsViewModel`; motor en `GeneratePlanUseCase`.
- **Estructura por días/semana** (1–7): 3 días → series + tempo + tirada larga; más días meten
  rodajes fáciles **alternados** (duro/fácil) para no encadenar calidad. Volumen progresivo (~+8%/sem,
  techo 10%), **80/20**, tirada larga como día más largo, taper la última semana.
- **Sesiones de calidad topadas** (series ≤ 9 km, tempo ≤ 14 km, larga ≤ 30 km): una serie es por
  repeticiones, no un balde de km. El sobrante va a fáciles → larga; si aún no cabe, **avisa subir
  días** en vez de inflar. A más días, la misma carga se **reparte** en sesiones más cortas (water-filling).
- **Ajustar** (`PlanConfigSheet`): selector de días/semana + días preferidos, con **vista previa en
  vivo** de la semana completa (con descansos) — WYSIWYG. Cada sesión se toca para el detalle.
- **Detalle de la sesión** (`WorkoutDetailView`): qué es, cómo se hace (series como "5 × 600 m
  fuerte" con cal./enf.), para qué sirve y **por qué ese número**. Ritmos cualitativos (no inventa
  ritmos exactos).
- **Enviar al Apple Watch** (`WatchWorkoutBuilder`, WorkoutKit): la sesión deja de ser lectura y se
  vuelve **ejecutable**. Desde el detalle, un botón manda el entrenamiento estructurado al reloj y
  la app **Entrenamiento nativa** lo corre: háptico y voz al cerrar cada repetición, avance solo
  entre pasos, y el workout termina en Salud → tu import lo levanta y cuenta para la adherencia.
  **Sin target de watchOS**: el motor ya vive en el reloj. La estructura en números es
  `WorkoutStructure`/`IntervalSpec`, y los textos de la guía se **derivan** de ella, así que la
  tarjeta y el reloj no pueden decir cosas distintas.
- **"Sugerir plan"** (como "Sugerir meta"): infiere de tu historial de carreras los días/semana, tus
  días y una meta de volumen (+20% en 8 sem); todo editable. `SuggestPlanUseCase`.
- **Solo carrera**: el volumen del plan usa sesiones de tipo carrera (no camina/senderismo).
- **Adherencia de la semana** → **[docs/adherencia.md](docs/adherencia.md)**. En corto: en la card
  de *Hoy*, sesiones y km hechos vs. planificados con barra y una frase; se toca para ver la semana
  **día por día** (qué pedía cada día y qué corriste). Cuenta **totales**, no calendario (mover una
  sesión no castiga); el volumen pesa el doble que la frecuencia y correr de más no pasa de 100%.
  Si te lesionas, te enfermas o toca **semana de descarga**, se marca en *Tu plan* y la adherencia
  **se pausa** (`WeekStatus`) en vez de marcarte 0% por haber hecho lo correcto; en lesión y
  enfermedad *Hoy* además deja de empujarte la sesión del día.
  Las **sesiones de calidad** se detectan por el tipo planeado **o** RPE ≥ 7, así que valen aunque
  muevas el tempo de día. De ahí sale el **aviso de sobreesfuerzo**: reprogramar está bien, pero
  deja un día fácil en medio — lo que lesiona es *encadenar* intensidad para compensar. Es aviso,
  no candado. Mide si seguiste el plan, **no** qué tan bien entrenaste (eso vive en *Progreso*).
  `PlanAdherence` · `PlanDayOutcome` · `WeekAdherenceView`.
- **Campañas** (`Campaign`, en *Objetivos*): tu meta principal convertida en **misiones de la
  semana** con las victorias marcadas desde datos reales — km del plan, sesiones del plan, y una
  misión por cada meta secundaria (peso, FC en reposo). El título es el de tu carrera objetivo (la
  próxima inscrita o prioritaria de esa distancia). **Derivada, no persistida**: se arma de la meta
  ancla + el plan + la adherencia + las metas, sin colección nueva ni CRUD. Una campaña a la vez.

### 🎯 Objetivos
- Metas del atleta (entidad `Goal`): **tiempo por distancia**, **VO₂max**, **peso**,
  **volumen semanal**, **FC en reposo** y **tirada larga**.
- **Auto-medibles** (Tier 1): VO₂max, volumen, FC en reposo y tirada larga se miden solas —
  no capturas nada. Volumen (7 d) y tirada larga (ventana de 8 sem) salen de tus
  **`TrainingSession`** (el mismo origen que la carga/ACWR, para que meta y carga nunca se
  contradigan); FC en reposo, de Salud **promediada a 7 días** (el dato de un día es muy ruidoso).
- **Progreso vs. datos reales**: tiempo vs. tus **PRs**, VO₂max y peso vs. tus datos de **Salud**
  (barra + "actual / faltan / ¡logrado!").
- **Sugerir meta** (sin IA): recomienda un objetivo realista y editable con fórmulas estándar —
  **Riegel** para tiempos (desde tu PR en otra distancia), VO₂max actual +3, peso hacia **IMC
  saludable** con tu estatura (acotado a una baja segura), volumen **+20% en 8 sem** (bajo el
  techo de ~10%/sem), tirada larga **~+1 km/sem**, y FC en reposo **−3 lpm en 12 sem** (con piso). Incluye **fecha objetivo sugerida**
  (una meta sin plazo no es accionable): peso a 0.5 kg/sem, tiempo/VO₂max ~12 semanas. Con su porqué.
- **Ritmo esperado** (`GoalPace`): con meta + fecha, muestra el desglose semanal (ej. *"≈ 0.5 kg
  por semana · ~12 semanas"*) para ir al ritmo correcto, no de golpe. **Reactivo** — se recalcula
  solo al editar la meta o la fecha (sin botón).
- **Vista "misión"** (rediseño): cada meta es una tarjeta con número héroe, barra de progreso
  clara, **"faltan X días"**, **confianza cualitativa** (Alta/Media/Baja, heurística Riegel/ritmo —
  no un % inventado) y **Coach Insight** narrativo con tus datos reales.
- CRUD con formulario por tipo (parseo `mm:ss`), fecha límite opcional. Fase 1 de la visión.

### 🏁 Carreras
- Alta/edición de carreras: nombre, fecha, costo, entrega de kit, prioridad.
- **Ubicación con búsqueda** (MapKit `MKLocalSearch`): busca por nombre, dirección o
  `lat,long`; vista previa en mapa; recuerda el texto previo al editar.
- Botón **"Cómo llegar"** que abre Apple Maps, Google Maps o Waze.
- **Añadir al Calendario** (carrera y entrega de kit) como eventos con coordenadas
  (→ mapa y tiempo de viaje del sistema), URL de inscripción y alarma. Acceso solo-escritura
  (privado); dedupe best-effort ("Ya en tu calendario").
- Detalle con **mapa de la ruta** (si la carrera se corrió y tiene GPS).
- **Readiness por carrera**: qué tan listo estás para cada distancia y **qué cambia según las
  semanas que faltan** — con 6 semanas te dice cuántas necesitas para subir la tirada larga a
  ritmo seguro (+1–2 km/semana); si no alcanzan, deja de pedírtelo y recomienda mantener o bajar
  de distancia; la última semana es de afinamiento y ya solo aconseja llegar descansado.
  `RaceReadiness.timing` + `AssessReadinessUseCase`; pruebas en `RunCalendarTests/RaceReadinessTests.swift`.
- **Recordatorios locales** (Perfil → Recordatorios): avisos de carrera (anticipado, víspera,
  día del evento), **entrega de kit** (víspera y día mismo, con lugar y hora), y de
  entrenamientos (a la hora, y un aviso de los que dejaste pendientes). Sin backend.

### 📅 Calendario (desde *Hoy*)
- Vista mensual con carreras y entrenamientos. Ya no es tab; se abre desde *Hoy*.

### 🏋️ Entrenar
- Entrenamientos de **carrera**, **CrossFit** (WOD), **caminata**, **senderismo** y **otro**,
  con duración, distancia y ritmo objetivo (las de distancia). Tipos en `TrainingType`.
- **Importación automática desde Apple Salud** al abrir la app (+ pull-to-refresh), con
  dedup (evita duplicar lo que ya registró el Apple Watch). Importa **todo el historial** y
  mapea el tipo de actividad de Salud (correr, caminar, senderismo, fuerza→CrossFit) al tipo
  de la app; las actividades no modeladas (ciclismo, natación) no se importan.
- **Mapa de ruta** interactivo por entrenamiento: animación del recorrido, velocidad,
  ritmo cardiaco por zona, distancia, y **splits** por km. Clima del día del entreno.
- **RPE por sesión** (esfuerzo 1–10) + **carga de sesión** (RPE × minutos). El RPE se
  **lee automáticamente del Apple Watch** (`workoutEffortScore`, iOS 18+) al importar;
  las ya importadas se rellenan solas (backfill idempotente). Si un entrenamiento reciente
  quedó **sin RPE**, una card discreta en Entrenar te invita a calificarlo de un toque.
- **Récords personales** (botón 🏅 en la barra de *Entrenar*) por distancia (5K/10K/15K/21K/42K):
  mejor tiempo, velocidad promedio, ritmo y progresión. Junta carreras con tiempo y
  entrenamientos, y sobre todo busca el **tramo más rápido dentro de cualquier corrida**
  (tu mejor 5K puede venir de una corrida de 10 km, igual que los récords del Apple Watch).
  Ver `BestSplit.fastestWindow`, `HealthKitService.fetchBestSplits` y `PersonalRecords`.
- Detalle de **solo lectura** (editar es explícito).

### 📈 Progreso · Condición (Apple Salud / HealthKit)
- **Resumen de forma**: VO₂max, FC en reposo, tendencia de fitness (Swift Charts interactivas).
- **Recuperación estimada** (orientativa, no médica): horas hasta estar recuperado a partir de
  **HRV (SDNN)**, **FC en reposo**, **carga reciente** (ponderada por RPE) y **sueño**.
- **Check-in diario** "¿cómo te sientes?" (1–5) + gráfica **"¿acierta el modelo?"**
  (sentido vs. predicho).
- **Calibración (segmentada)**: aprende de tus check-ins no solo un sesgo global sino cuánto se
  desvía el modelo en **condiciones adversas** (HRV baja, sueño corto, carga alta) y corrige
  extra los días que aplican. Se activa con ~2 semanas de registros.
- **Carga de entrenamiento (ACWR)**: ratio agudo:crónico con zonas (óptimo / riesgo),
  ponderada por **esfuerzo (RPE)** — una sesión intensa pesa más que una suave de igual duración.
- Cards **educativas** por métrica (qué es, rangos por edad, tu valoración).
- **Review semanal** (fase 2): peso · cintura · energía · hambre. Las medidas se escriben en
  **Salud**; energía y hambre van a `bodyLogs`. Card en *Hoy* los **domingos**, que desaparece
  al registrarlo. La **cintura** detecta **recomposición** (peso estancado + cintura bajando) y
  lo dice en el Coach Insight de la meta de peso: es progreso real que la báscula esconde.

### 👤 Perfil (avatar en *Hoy*)
- Se abre desde el avatar de la barra superior en *Hoy* (ya no es tab). Datos del usuario y **cierre de sesión**.
- **Recordatorios**: preferencias de las notificaciones locales (carreras, entrega de kit,
  entrenamientos). Ver `RemindersSettingsView` / `RemindersViewModel`.

---

## Arquitectura

```
Presentation  ──▶  Domain  ◀──  Data
 (SwiftUI +         (Entities,      (Firebase Auth +
  ViewModels)        UseCases,       Firestore;
                     Repo protocols)  implementaciones)
        ▲                                  ▲
        └──────────  App / DI  ────────────┘
                 (AppContainer = composition root)
```

| Capa | Carpeta | Responsabilidad |
|------|---------|-----------------|
| **Domain** | `RunCalendar/Domain` | Entidades, protocolos de repositorio y casos de uso. Swift puro, sin Firebase ni SwiftUI. |
| **Data** | `RunCalendar/Data` | DTOs, mapeo y implementaciones de los repositorios con Firebase. |
| **Presentation** | `RunCalendar/Presentation` | Vistas SwiftUI + ViewModels (`@Observable`). Solo conoce casos de uso. |
| **App / DI** | `RunCalendar/App` | `AppContainer` arma el grafo de dependencias e inyecta todo. |

Cada caso de uso tiene **una sola responsabilidad** (SRP) y recibe su repositorio por
**protocolo** (Dependency Inversion). La UI nunca toca Firebase directamente.

---

## Requisitos

- macOS con **Xcode 26+**
- **XcodeGen** (`brew install xcodegen`) — el `.xcodeproj` se genera, no se commitea
- Una cuenta de **Firebase** y (para Sign in with Apple) de **Apple Developer**

---

## Puesta en marcha

### 1. Generar el proyecto

```bash
brew install xcodegen          # si no lo tienes
xcodegen generate              # crea RunCalendar.xcodeproj
open RunCalendar.xcodeproj
```

### 2. Crear el proyecto en Firebase

1. Entra a <https://console.firebase.google.com> → **Agregar proyecto**.
2. Agrega una app **iOS** con el bundle id: `com.fercho.runcalendar.app`
   (o cambia el id en `project.yml` y vuelve a generar).
3. Descarga **`GoogleService-Info.plist`** y colócalo en:
   `RunCalendar/Resources/GoogleService-Info.plist`
   *(está en `.gitignore`; nunca lo subas al repo.)*
4. En la consola, activa:
   - **Authentication → Sign-in method →** Email/Password, Apple **y Google**.
   - **Firestore Database →** crea la base en modo producción.

### 3. Configurar Google Sign-In

1. En **Authentication → Sign-in method**, habilita **Google** y guarda.
2. **Descarga de nuevo** el `GoogleService-Info.plist` (ahora incluye `CLIENT_ID` y
   `REVERSED_CLIENT_ID`) y reemplaza el de `RunCalendar/Resources/`.
3. Crea el archivo **`RunCalendar/Resources/Secrets.xcconfig`** (está en `.gitignore`) con:
   ```
   REVERSED_CLIENT_ID = <el valor REVERSED_CLIENT_ID de tu GoogleService-Info.plist>
   ```
   Ese valor alimenta el URL scheme del `Info.plist` (necesario para el callback de Google).
4. Corre `xcodegen generate`.

### 4. Configurar Sign in with Apple

1. Pon tu **Team ID** en `RunCalendar/Resources/Secrets.xcconfig` (gitignored):
   `DEVELOPMENT_TEAM = XXXXXXXXXX`. Persiste al regenerar y no se sube al repo.
2. La capability **Sign in with Apple** ya está declarada en
   `RunCalendar/Resources/RunCalendar.entitlements`.
   > ⚠️ Requiere **membresía de pago** de Apple Developer: los equipos personales
   > (cuenta gratis) no la soportan. Para probar en dispositivo con cuenta gratis,
   > quita temporalmente la key `com.apple.developer.applesignin` del entitlements.
3. En Firebase, en el proveedor **Apple**, configura el **Service ID** / OAuth según la
   [guía oficial](https://firebase.google.com/docs/auth/ios/apple).

### 5. Reglas de seguridad de Firestore

Cada usuario solo accede a sus propios datos. Pega esto en **Firestore → Reglas**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // El documento del perfil (users/{uid}) y todas sus subcolecciones.
    // En rules v2 el wildcard {document=**} NO cubre el documento padre,
    // por eso se declara la regla del propio users/{userId} por separado.
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

### 6. Apple Health (HealthKit)

La pestaña **Condición** lee entrenamientos y datos de forma física de Salud.

- Capability **HealthKit** declarada en `RunCalendar/Resources/RunCalendar.entitlements`
  y el permiso `NSHealthShareUsageDescription` en `project.yml`.
- **Solo iPhone/Watch:** HealthKit no existe en Mac; en Mac la pestaña muestra
  "disponible en iPhone".
- Para leer tu **historial real del Apple Watch**, corre la app en tu **iPhone físico**
  (el Simulador no tiene tu historial). Con cuenta de desarrollador **gratuita** se
  puede probar en tu dispositivo; la de pago solo es necesaria para distribuir.

### 7. Compilar y correr

- **iPhone:** elige un simulador o tu dispositivo y ⌘R.
- **Mac:** en el selector de destino elige **My Mac (Designed for iPad)** y ⌘R.

---

## Modelo de datos (Firestore)

```
users/{uid}                          # perfil
users/{uid}/races/{raceId}           # carreras
users/{uid}/trainings/{id}           # entrenamientos (cualquier TrainingType; incluye rpe)
users/{uid}/recoveryLogs/{yyyy-MM-dd} # check-in diario de recuperación (para calibrar)
users/{uid}/goals/{goalId}           # objetivos del atleta (tiempo/VO₂max/peso)  (fase 1)
users/{uid}/bodyLogs/{yyyy-MM-dd}    # review semanal: energía y hambre (fase 2)
```

> **El plan de entrenamiento (fase 3) no se persiste.** Es una función pura de tus metas + volumen
> de carrera + config, así que se recalcula cada vez (siempre consistente). Lo único que se guarda es
> la **`PlanConfig`** (días/semana + días preferidos) en **UserDefaults** — dato local del dispositivo.
> `// ponytail:` muévela a Firestore si importa el sync multi-dispositivo.

> **HealthKit no vive en Firestore.** VO₂max, HRV, FC, workouts y rutas se leen del
> dispositivo en cada sesión (nunca se suben). Lo único que persiste de Condición son los
> **check-ins** (`recoveryLogs`) y el review semanal (`bodyLogs`). Por eso Condición solo
> funciona en iPhone/Watch, no en Mac.
>
> **Peso y cintura son la única escritura de la app en Salud** (`bodyMass`,
> `waistCircumference`). Se guardan ahí y no en Firestore: así el historial y la
> sincronización con la app Salud salen gratis, y el progreso de la meta de peso —que ya
> leía de Salud— se mueve solo. Por eso `bodyLogs` guarda **solo lo subjetivo**.

### Modelo de datos futuro (tentativo)

Boceto para que las fases de la visión se implementen con estructura consistente. Todo cuelga
de `users/{uid}/…` y hereda las mismas reglas de seguridad. **Aún no existe** — es guía de diseño.

```
users/{uid}/goals/{goalId}          # ✅ fase 1 (ya existe): tipo, targetValue, startValue, distance, deadline
users/{uid}/plan/{planId}           # plantilla del plan (semanas, días)                       (fase 2)
users/{uid}/plan/{planId}/days/{d}  # día planificado: tipo, descripción (p. ej. 8×1'/2')       (fase 2)
users/{uid}/bodyLogs/{yyyy-MM-dd}   # ✅ fase 2: energía y hambre (peso/cintura viven en Salud)
users/{uid}/strength/{sessionId}     # fuerza: ejercicio × peso × reps; PR de levantamiento      (fase 4)
users/{uid}/nutrition/{profileId}   # objetivos: kcal, macros, hidratación             (post-MVP, ver Pendientes)
```

Notas: la **adherencia** del plan ya existe y **no** persiste nada — se calcula cruzando el plan de
la semana (derivado) con las `TrainingSession.completed`; persistir `plan/{planId}` es justamente lo
que falta para tener adherencia **histórica** (ver [Pendientes](docs/pendientes.md)). El **review
corporal** reusa el patrón de `recoveryLogs`. La **nutrición** sale del MVP; si vuelve, se acota a
*objetivos + adherencia (checkbox)*, no a un registro de alimentos.

---

## Estructura de carpetas

```
RunCalendar/
├── App/            # @main, AppDelegate (Firebase), RootView, DI/AppContainer
├── Core/           # utilidades, componentes y extensiones reutilizables (Neon, Haptics, Log…)
├── Domain/         # Entities · Repositories (protocolos) · UseCases
├── Data/           # DTO · Repositories (Firebase) · Services (HealthKitService, etc.)
├── Presentation/   # Auth · Races · Training · Calendar · Health · Root (vistas + ViewModels)
└── Resources/      # Assets, entitlements, GoogleService-Info.plist (lo pones tú)
```

---

## Mapa del código (para retomar rápido)

Índice de "dónde vive qué", para no buscar a ciegas.

### Entrada y wiring
- `App/…App.swift` (`@main`) → `AppDelegate` (init de Firebase) → `RootView` (gate de auth) → `MainTabView`.
- `App/DI/AppContainer.swift` — **composition root**: crea repos, services y los `makeXxxViewModel(...)`.
- `Presentation/Root/MainTabView.swift` — **dueño de todos los ViewModels**; monta los 4 tabs (Hoy/
  Entrenar/Objetivos/Progreso), arranca
  los streams de Firestore (`.task { … start() }`) y los observadores de Salud (`HKObserverQuery`).
  También dispara la **carga inicial de Condición** (`healthViewModel.onAppear()`) aquí, no solo en
  la tab Progreso: la card de recuperación de *Hoy* la necesita aunque nunca abras Progreso.

### ViewModels (`@Observable`, en `Presentation/*/`) y sus dependencias cruzadas
> El acoplamiento entre ViewModels **no es obvio** y es fácil tropezar: varios reciben a otros por constructor.

| ViewModel | Rol | Recibe |
|-----------|-----|--------|
| `AuthViewModel` | Login / sesión | — |
| `RacesViewModel` | Carreras (stream Firestore) | — |
| `TrainingViewModel` | Entrenamientos + import de Salud | — |
| `HealthViewModel` | Condición | **`TrainingViewModel`** (sus `sessions` alimentan la carga de recuperación/ACWR) |
| `RemindersViewModel` | Agenda notificaciones locales | **`RacesViewModel` + `TrainingViewModel`** |
| `ProfileViewModel` | Perfil | — |
| `GoalsViewModel` | Objetivos **y el plan (fase 3)** | **`RacesViewModel` + `TrainingViewModel`** (PRs y volumen de carrera) |

### Dominio (`Domain/Entities/`) — sustantivos clave
- **Carreras**: `Race`, `RaceDiscipline` (5/10/15/21/42K, Trail, Otra), `RaceStatus`, `RaceReadiness`.
- **Entrenamiento**: `TrainingSession` + `TrainingType` (Carrera/CrossFit/Caminata/Senderismo/Otro),
  `HealthWorkout` (lo que se lee de Salud antes de importar). Ojo: `effortMinutes` (duración×RPE/5) y
  `sessionLoad` (RPE×min) viven en `TrainingSession`.
- **Condición**: `RecoverySnapshot`/`RecoveryEstimate`/`RecoveryTrend` (`Recovery.swift`),
  `RecoveryCheckIn`, `RecoveryCalibration`, `WorkloadInput`/`WorkloadRatio`/`WorkloadZone`
  (`Workload.swift`), `FitnessSummary`, `FitnessTrend`, `WorkoutRoute`, `RaceWeather`.
- **Cuerpo** (fase 2): `BodyMeasure` (peso/cintura: unidad y rango válido), `MeasurementEntry`
  (un registro leído de Salud), `BodyLog` (review semanal: energía, hambre, notas).
- **Plan** (fase 3, `TrainingPlan.swift`): `TrainingPlan`, `PlannedDay`, `PlanConfig`,
  `PlannedWorkoutKind` (largo/tempo/series/fácil), `GoalRole` (driver/parámetro/resultado +
  `GoalType.planRole`), `WorkoutGuide`/`GuideStep` (detalle de sesión), `PlanSuggestion`.
- **Otros**: `AppUser`, `UserProfile`, `ReminderPreferences`, `CalendarEvent`.

### Casos de uso (`Domain/UseCases/`)
Uno por responsabilidad (SRP), agrupados por archivo (`HealthUseCases.swift`, `RaceUseCases.swift`,
`TrainingUseCases.swift`, `AuthUseCases.swift`, `PlanUseCases.swift`, …). Patrón: `Fetch*` (lee del repo)
y `Assess*`/`Compute*`/`Generate*` (lógica pura). Los de carga/condición: `FetchRecovery`/`AssessRecovery`,
`FetchWorkload`/`AssessWorkload`, `AssessReadiness`, `ComputeTrainingLoad`, `FetchFitnessSummary`/`FetchFitnessTrend`.
Los del **plan** (puros, sin repo): `GeneratePlanUseCase` (el motor), `InferPrimaryGoalUseCase`
(meta driver), `DescribeWorkoutUseCase` (guía de la sesión), `SuggestPlanUseCase` (sugerir desde historial).

### Data (`Data/`)
- **Repos** `Firestore*Repository` implementan los protocolos de `Domain/Repositories`.
- **Services**: `HealthKitService` (todas las queries de Salud), `EventKitService` (Calendario),
  `OpenMeteoService` (clima REST), `LocalNotificationService`, `GoogleSignInService`,
  `WatchWorkoutBuilder` (sesión del plan → entrenamiento de Apple Watch, WorkoutKit).
- **DTOs** en `Data/DTO` mapean Firestore ↔ entidades.

### Core (`Core/`)
Transversal: `Theme/Neon.swift` (paleta adaptable claro/oscuro), fuentes (`.mCaption`, `.mTitle3`…),
`Haptics`, `Log`. **Todo cambio de color/tipografía va aquí** para que aplique a toda la app.

**Logging y crashes** (`Core/Utils/Log.swift`): `Log.health.info(...)` para el log del sistema
(`os.Logger`, visible en Console.app por subsistema/categoría), y en los `catch`
**`Log.health.failure("contexto", error)`** — escribe al log **y** manda el fallo no fatal a
Crashlytics. Usa `failure` en todo `catch` nuevo: es el único punto donde se conecta el reporte,
así que basta con eso para que aparezca en el panel.

El `context` es texto nuestro, **nunca datos del usuario**: viaja a un servicio externo. En Debug
el reporte está apagado (`Log.configureCrashReporting`), y los dSYM se suben en un
`postBuildScript` solo en Release.

---

## Diseño / UI

Identidad visual y piezas reutilizables, para que cualquiera (o una IA) rediseñe **coherente**
con lo que ya existe. Todo lo transversal vive en `Core/` — **cambios de estilo se hacen ahí**,
no por pantalla.

### Identidad

- **Dos tipografías** (`Core/Theme/Fonts.swift`), como el UI Kit:
  - **Permanent Marker** (`Font.marker(_:)`) solo para **títulos grandes** (`.mLargeTitle`, `.mTitle3`)
    y **números destacados** (número héroe de una meta, splits, etc. — vía `.marker(size)` explícito).
    Da el aire "deportivo/hecho a mano" sin saturar.
  - **Fuente del sistema (San Francisco)** para cuerpo, filas, descripciones y captions
    (`.mHeadline … .mCaption2` mapean a los estilos nativos). Limpia, cercana a Inter, Dynamic Type.
    Se eligió SF sobre bundlear Inter (nativo, cero peso; ~95% del look del Kit).
- **La app es dark-only.** `UIUserInterfaceStyle: Dark` en `project.yml` (no
  `.preferredColorScheme`, para que también cubra lo que presenta UIKit: alertas, teclado, hojas de
  Salud/Calendario). La identidad `Neon` es dark-first y mantener una paleta clara en paralelo
  significaba diseñar cada card dos veces. **No agregues variantes claras ni ramas `colorScheme`.**
- **Paleta `Neon`** (`Core/Theme/Neon.swift`): valores del **RunCalendar UI Kit** — `accent`
  `#3D8BFF`, `green` `#34D399` (esmeralda), `teal` `#2DD4CE`, `orange` `#FF9F45`, `purple`
  `#A78BFA`, `pink` `#FF6FA8`, `gold` `#FFD166`. Degradados `buttonGradient` (azul→púrpura) y
  `logoGradient` (arcoíris de branding).
  **Cambia aquí y se propaga a toda la app.** Superficies del Kit (`Neon.background`/`surface`/
  `surfaceElevated`) aplicadas en **todas las pestañas** (fondo `Neon.background`
  + `scrollContentBackground(.hidden)` + filas `Neon.surface`). El cuerpo usa SF en vez de Inter (nativo, cero peso).
- **`ProgressRing`** (`Core/Components`): anillo del Kit (pista tenue + arco de color, contenido al
  centro). Reutilizable — en **recuperación**, **ACWR** (fracción `ratio/1.5×`) y **readiness**
  (% = promedio de avance en carrera larga y volumen vs. lo recomendado).
- **Tono**: oscuro-primero, acentos neón, mucho espacio en blanco, datos siempre **rotulados con
  unidades** (nunca un número pelón).

### Componentes reutilizables

| Pieza | Dónde | Uso |
|-------|-------|-----|
| `EmptyStateView(icon,title,message)` | `Core/Components` | Estado vacío consistente |
| `NeonButtonStyle` | `Core/Theme` | Botón primario (degradado, esquina 12) |
| `MetricRow` + `MetricInfoCard` | `Presentation/Health` | Fila de métrica con **card educativa** (qué es, rangos, tu valoración) |
| `chartSelectionMark(...)` | `Presentation/Health/ChartSupport` | Tooltip de selección para Swift Charts |
| `RPEPromptCard` | `Presentation/Training` | Card discreta descartable (patrón "pendiente de completar") |
| `.shimmering()` | `Core/Components/Shimmer.swift` | Brillo animado para skeletons de carga (sobre placeholders `.redacted`) |
| `RecoveryAccuracyChart` / `*TrendChart` | `Presentation/Health` | Gráficas interactivas (`chartXSelection`) |
| chips (`chip(...)`) | Detalle de carrera/entreno | Etiquetas de estado (Completado, Prioritario) |
| `Haptics` | `Core/Utils` | Feedback al guardar/confirmar |

### Patrones de interacción

- **Listas** como base; **pull-to-refresh** para recargar (carreras, entrenamientos).
- **Swipe actions** (eliminar / marcar hecho) en filas.
- **Sheets** para formularios de alta/edición; **`confirmationDialog`** para duplicados/decisiones.
- **Cards descartables** para avisos no bloqueantes (ver `RPEPromptCard`).
- **Skeletons de carga** (`.redacted(reason: .placeholder)` + `.shimmering()`): cada sección
  carga por su cuenta sin bloquear la navegación — mientras llega el dato se muestra su silueta
  con brillo, no un spinner que tape la pantalla. En uso en la recuperación de *Hoy* y el `.loading`
  de *Progreso*.
- **Cards educativas** en Condición: cada métrica explica importancia + rango + valoración
  (es una preferencia de producto, no adorno).

### Dirección de rediseño (en curso)

La UI actual usa `Form`/`List` agrupado por defecto → se siente "cuadrada" y genérica. El rediseño
la mueve de **"llenar un formulario" a "crear una misión"**, con más carácter de la identidad `Neon`.
Patrones objetivo (empezando por **Objetivos** como buque insignia, luego al resto de tabs):

- **Número protagonista (hero)**: el dato clave enorme (p. ej. `21K · 1:59:59`), no una fila más.
- **"Faltan 84 días"** en vez de una fecha suelta (el cerebro entiende mejor el tiempo restante).
- **Coach Insight**: explica el *porqué* con datos reales (`VO₂max 51 · 35 km esta semana · PR 5K 27:00
  · ~12 sem de prep`), en vez de una línea escondida tipo "basado en tu PR…".
- **Confianza cualitativa** (Alta / Media / Baja) con sus razones — **nunca un % inventado** (finge
  precisión y erosiona confianza; mismo principio que la calibración).
- **Cards reutilizables** (fondo, esquinas, sombra) + número héroe extraídos a `Core`, para que el
  look aplique en **toda** la app, no pantalla por pantalla.

### Al mejorar UI/UX

Reusa la tabla y los patrones de arriba antes de crear componentes nuevos; respeta la paleta `Neon`
(no colores sueltos) y las fuentes `.m*`; y recuerda que un cambio de estilo debe verse en **todos
los tabs**, no en una pantalla.

---

## Troubleshooting

| Síntoma | Causa / solución |
|---------|------------------|
| **La ruta del mapa no se pinta** | El workout es viejo y no tiene GPS, o Salud no autorizó `workoutRoute`/FC. Corre en iPhone físico y acepta los permisos. Carreras de hace años (p. ej. 2018) suelen no traer ruta. |
| **Condición dice "disponible en iPhone"** | Estás en Mac. HealthKit no existe en macOS. |
| **No aparece mi historial de Salud** | El Simulador no tiene tu historial: usa tu **iPhone físico**. |
| **El RPE no llega solo del Apple Watch** | Solo iOS 18+ expone `workoutEffortScore`, y solo si calificaste el esfuerzo en el reloj. Si no, el RPE queda vacío y se pone editando. |
| **La calibración no se activa** | Necesita ~14 check-ins en días distintos. Para probar ya, usa el botón **"Sembrar 18 check-ins (debug)"** en Condición (solo builds DEBUG; en memoria, no persiste). |
| **Sign in with Apple falla en dispositivo** | Cuenta gratis de Apple Developer no soporta la capability. Quita `com.apple.developer.applesignin` del entitlements **en local** (no lo commitees). |
| **"Cannot find type…" en Xcode pero compila** | Ruido del índice de SourceKit en frío. Confía en `xcodebuild` (BUILD SUCCEEDED). |
| **Archivo nuevo no compila** | XcodeGen no lo conoce: corre `xcodegen generate` (el `.xcodeproj` está gitignored). |
| **"Salud no deja que Rumbo escriba…"** | Falta el permiso de **escritura** (no el de lectura: la medida aparece en ambos bloques). Salud › tu foto › Apps y servicios › Rumbo › bloque *escribir datos*. Si el bloque no existe, **borra y reinstala** la app: iOS no vuelve a mostrar la hoja una vez denegada. |

---

## Notas para desarrolladores / IA

Contexto que **no** se deduce del código y ahorra tropiezos:

- **Flujo de trabajo**: cada feature va en su **rama** desde `main`, se verifica con
  `xcodebuild -scheme RunCalendar -destination 'generic/platform=iOS' build`, y luego
  **issue → commit → PR → squash-merge → cerrar issue**. Commits/PRs en español.
- **XcodeGen**: el `.xcodeproj` **no se commitea**; se regenera. `sources` globa la carpeta
  `RunCalendar`, así que archivos nuevos entran al regenerar.
- **Nunca commitear**: `RunCalendar/Resources/RunCalendar.entitlements` cuando tenga cambios
  locales (quitar Apple Sign-In para cuenta gratis), `GoogleService-Info.plist`,
  `Secrets.xcconfig` (ambos gitignored).
- **Cuenta de Apple gratis**: sin App Groups, WeatherKit ni capabilities de pago. Por eso el
  widget está en el backlog y el clima usa **Open-Meteo** (REST) en vez de WeatherKit.
- **Idioma**: identificadores y tipos en **inglés**; textos de UI, comentarios, commits y PRs en
  **español**. Mantén esa división.
- **Pruebas** (`RunCalendarTests`, Swift Testing): 51 pruebas en 9 suites. Se corren con ⌘U o con
  ```bash
  xcodebuild test -scheme RunCalendar -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
  ```
  Hospedadas en la app (`@testable import RunCalendar`), así que alcanzan casos de uso, no solo
  entidades. Cubren `BestSplit`, `RaceReadiness.timing`, adherencia/campañas/`WeekStatus`,
  `WorkoutStructure` y el motor **`GeneratePlanUseCase`**. Antes eran scripts sueltos en `Scripts/`
  que había que invocar a mano; ya no existen.
  Al motor se le prueban **invariantes** (80/20, techo de progresión, tirada larga como día más
  largo, taper), no números exactos: las constantes están sin calibrar a propósito y fijarlas
  cementaría valores que nadie ha comprobado. Ver *Umbrales sin calibrar* en
  [Pendientes](docs/pendientes.md).
  Sigue faltando **CI** y dobles de repositorio para llegar a los ViewModels.
- **Convenciones de código**:
  - ViewModels `@Observable`; la UI solo conoce **casos de uso** (nunca Firebase directo).
  - Cada caso de uso = una responsabilidad, recibe su repositorio por **protocolo**.
  - Estilo visual centralizado en `Core` (paleta `Neon`, `Haptics`, `Log`, fuentes `.mCaption`…).
    Cambios de fuente/diseño se aplican en **toda** la app, no en una sola pantalla.
  - Atajos deliberados se marcan con comentarios `// ponytail:` (nombran el techo y el upgrade).
- **HealthKit**:
  - Es **a nivel dispositivo** (no per-usuario Firestore). Se lee en cada sesión; nada se sube.
  - `HealthKitService` concentra las queries (`HKStatisticsCollectionQuery`, rutas,
    `HKWorkoutEffortRelationshipQuery` para el RPE, HRV `SDNN`, sueño, VO₂max).
  - La recuperación es un **modelo heurístico** en `AssessRecoveryUseCase`: horas base por carga
    × factores de HRV/FC/sueño × **factor de calibración**. Todas las constantes son
    calibrables (marcadas `ponytail:`).
  - **Calibración** (`RecoveryCalibration`): modelo **aditivo** aprendido de los check-ins —
    sesgo global `b0` + offsets por condición adversa (HRV baja, sueño corto, carga alta),
    resueltos para las condiciones de hoy. Robusto e interpretable; una regresión continua
    sería el paso a v3 con muchos más registros. El check-in guarda `loadMinutes` para el
    segmento de carga (los previos a esta versión quedan sin él, en `nil`).
- **Puente RPE → recuperación/ACWR**: la carga sale de las `TrainingSession` (que ya incluyen lo
  importado de Salud), ponderada por esfuerzo vía `effortMinutes` (duración × RPE/5; RPE 5 =
  minutos crudos). `ComputeTrainingLoadUseCase` deriva la carga de 72 h (recuperación) y 7 d/28 d
  (ACWR); `HealthViewModel` la inyecta con `RecoverySnapshot.withLoad(...)` y recalcula al cambiar
  las sesiones (`reloadIfLoaded`). Sin sesiones (arranque en frío) cae a los minutos de HealthKit.

---

## Roadmap y backlog

**Visión (objetivo final):** que RunCalendar sea la app del **atleta serio** que quiere mejorar con
**métricas fiables** — no solo registrar, sino *entrenar con propósito*. El endgame es un **modelo de
IA** que, sobre tus objetivos, tu plan, tu adherencia y tus tendencias reales, genere **planes de
entrenamiento y de alimentación personalizados** y te entregue **reportes por correo**. El artefacto
objetivo es un [Manual del Atleta Híbrido](docs/ejemplo-manual-atleta.md) (objetivos → carrera +
técnica + hidratación → nutrición/macros → seguimiento) — hoy hecho a mano; la app debería generarlo.
La base de métricas fiables ya existe; falta la estructura (objetivos, plan, fuerza) sobre la que la
IA pueda razonar — por eso la IA es la **última** fase, no la primera. La **nutrición sale del MVP**:
la primera versión del reporte razonará sobre entrenamiento y condición, no sobre alimentación.

**No competimos contra Strava/Garmin; competimos contra el papel.** La app es el **dashboard**; el
[Manual](docs/ejemplo-manual-atleta.md) es la **fuente de conocimiento/metodología**. Cada mañana el
atleta debería abrir la app y encontrar respuesta a **cuatro preguntas** (que definen la nav objetivo
*Objetivos → Plan → Hoy → Progreso*):

1. ¿Cuál es mi objetivo principal ahora?
2. ¿Qué debo hacer hoy para acercarme?
3. ¿Cómo voy respecto al plan?
4. ¿Qué aprendí esta semana?

**Modelo de "Campañas" (capa de UX que une Fases 1–3):** en vez de perseguir un número suelto, un
**Proyecto/Campaña** (p. ej. *"Primer Medio Maratón"*) agrupa el **objetivo principal** (21K en 2:00)
+ sus **misiones** — checklist accionable (correr 40 km esta semana, 3 fartlek, bajar a 80 kg, dormir
8 h × 7, meal prep dominical…). Persigues pequeñas victorias, no un número lejano. Las misiones **salen
del plan (Fase 3) y del Manual**; hasta entonces son checklist manual. Llega cuando exista el plan.

**Plan por fases (hacia la visión):**

| Fase | Qué | Notas |
|------|-----|-------|
| **1. Objetivos** ✅ | Entidad `Goal` + CRUD + tab con progreso (tiempo vs. PRs, VO₂max/peso vs. Salud) y **"Sugerir meta"** (Riegel/IMC, sin IA) | Marco del que cuelga todo; también abre el rediseño de navegación |
| **2. Review dominical** ✅ | Check-in semanal: peso y cintura (→ Salud) + energía y hambre (→ `bodyLogs`), con card en *Hoy* los domingos. **Fotos pendientes** (requieren Firebase Storage) | Reusa el patrón de `recoveryLogs`. La **cintura** detecta *recomposición*: peso estancado pero cintura bajando |
| **3. Plan + Campañas** ✅ | **Generación automática** de la semana (motor determinista sin IA), **misión de hoy** en Hoy, **detalle** de sesión, **"Sugerir plan"** desde historial, preview con descansos, **adherencia** de la semana y **Campañas** (misiones derivadas del plan + las metas) | Responde "¿qué hago hoy?" y "¿cómo voy?". Ver [Plan](#-plan-fase-3) |
| **4. Fuerza** | Registro de fuerza + **PR de levantamiento** (dominio nuevo: ejercicio × peso × reps). La mitad **híbrida** del producto | Es la brecha más grande entre lo que la app promete y lo que hace: hoy solo sirve a corredores |
| **5. IA + reportes** | Claude API razona sobre 1–4 → plan/reporte tipo Manual; entrega por correo | Requiere backend (Firebase Functions); **la API key vive en el backend, nunca en la app**. Indefendible sin target de pruebas (ver [Pendientes](docs/pendientes.md)) |
| ~~Nutrición~~ | **Movida a post-MVP.** Incluso acotada (objetivos + checkbox, sin food-logger) arrastra dominio, UI y un modelo de adherencia propios | Demasiado para ahora y no es lo que sostiene el MVP. Detalle en [Pendientes](docs/pendientes.md#post-mvp) |

> **Reestructura UX:** ✅ hecha en su mayoría — 4 tabs por *ciclo del atleta* (**Hoy · Entrenar ·
> Objetivos · Progreso**), Carreras/Calendario dentro de Hoy, Perfil como avatar. **Hoy** ya tiene la
> **misión del día** (Fase 3); la config del plan se abre desde ahí. Falta decidir si el plan merece
> **tab propia** (hoy vive en Hoy/Objetivos) — se promoverá si se gana el espacio.
>
> **Rediseño visual (RunCalendar UI Kit):** ✅ en su mayoría — paleta, tipografía (Permanent Marker en
> display + San Francisco en cuerpo), **superficies dark-first** en todas las tabs, **`ProgressRing`**
> (recuperación/ACWR/readiness) y la vista **"misión"** en Objetivos. **Dark-only decidido** ✅ (la app
> fija el estilo oscuro; no hay paleta clara). Pendiente: rodar el look "misión" a más pantallas.
> Patrones en [Diseño / UI](#dirección-de-rediseño-en-curso).
>
> Boceto de colecciones para estas fases: ver [Modelo de datos futuro](#modelo-de-datos-futuro-tentativo).

**Hecho** (resumen): importación auto de Salud (todos los tipos, incl. "Otro") + rutas + splits,
búsqueda de ubicación + "Cómo llegar", Condición completa (recuperación, ACWR, VO₂max, tendencias,
PRs), readiness por carrera, RPE por sesión + esfuerzo del Watch, calibración **segmentada**
(por HRV/sueño/carga), **carga de recuperación/ACWR ponderada por RPE**, distancia 15K,
caminata/senderismo, recordatorios locales (carreras, kit con lugar/hora, entrenamientos + pendientes),
exportar carreras/kit al Calendario (EventKit, con coordenadas/URL/alarma). **Objetivos** con confianza
cualitativa, Coach Insight y ritmo semanal esperado. **Rediseño del Kit** (paleta/tipografía/superficies/
rings) y **navegación por ciclo del atleta** (Hoy · Entrenar · Objetivos · Progreso). **Plan (Fase 3):**
generación automática de la semana (motor determinista), misión de hoy, detalle de sesión, "Sugerir plan"
desde historial, preview con descansos, **adherencia de la semana** y **Campañas** (misiones derivadas).

## Pendiente

Backlog completo, priorizado y con el porqué de cada prioridad: **[docs/pendientes.md](docs/pendientes.md)**.

Lo que hay que saber sin abrirlo:

| | |
|---|---|
| **P0 · roto hoy** | *vacío* — el modo lesión/enfermedad ya existe (`WeekStatus`) |
| **Bloqueado** | **Sign in with Apple**: falta cuenta de pago en el Apple Developer Program, así que la capability no se puede habilitar y Xcode quita el entitlement al firmar. Email/contraseña y Google funcionan |
| **P1 · antes de tener usuarios** | **Observabilidad**: Crashlytics ✅ + no fatales ✅ (`Logger.failure`); faltan 4–5 eventos de uso · **pruebas**: target ✅ + 51 pruebas ✅; faltan **CI** y dobles de repositorio para llegar a los ViewModels |
| **P2 · deuda con costo** | Huecos de la adherencia (distribución de la carga, histórico, entorno) · duración en minutos enteros · periodización lineal · umbrales sin calibrar |
| **P3 · extensiones** | **Fuerza** (Fase 4) · tab Plan · campañas persistidas · fotos del review · widget · Watch · catálogo compartido |
| **Post-MVP** | **Nutrición** |
