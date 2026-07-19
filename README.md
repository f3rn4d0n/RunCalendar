# RunCalendar 🏃‍♂️

App para iPhone y Mac que reúne tu **calendario de carreras** (ubicación, costos, entrega de
kits, fecha), tu **programa de entrenamiento** (CrossFit y carrera) y tu **condición física**
(recuperación, carga y forma leídas de Apple Salud), con login.

Construida con **SwiftUI**, **Clean Architecture**, **SOLID** y **Firebase** (Auth + Firestore).

> **¿Eres otra IA o dev retomando el proyecto?** Empieza por [Funcionalidades](#funcionalidades)
> (qué existe hoy) y el [Mapa del código](#mapa-del-código-para-retomar-rápido) (dónde vive qué +
> cableado de ViewModels), luego [Notas para desarrolladores](#notas-para-desarrolladores--ia)
> (convenciones y trampas) y [Troubleshooting](#troubleshooting). El [Roadmap](#roadmap-y-backlog)
> tiene la visión y lo pendiente.

---

## Funcionalidades

Seis pestañas: **Carreras**, **Calendario**, **Entrenar**, **Objetivos**, **Condición** y **Perfil**.

### 🎯 Objetivos
- Metas del atleta: **tiempo por distancia**, **VO₂max** y **peso** (entidad `Goal`).
- **Progreso vs. datos reales**: tiempo vs. tus **PRs**, VO₂max y peso vs. tus datos de **Salud**
  (barra + "actual / faltan / ¡logrado!").
- **Sugerir meta** (sin IA): recomienda un objetivo realista y editable con fórmulas estándar —
  **Riegel** para tiempos (desde tu PR en otra distancia), VO₂max actual +3, y peso hacia **IMC
  saludable** con tu estatura (acotado a una baja segura). Incluye **fecha objetivo sugerida**
  (una meta sin plazo no es accionable): peso a 0.5 kg/sem, tiempo/VO₂max ~12 semanas. Con su porqué.
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
- **Readiness por carrera**: qué tan listo estás para cada distancia, consciente de la
  fecha (una 5K esta semana vs. una 42K la próxima).
- **Recordatorios locales** (Perfil → Recordatorios): avisos de carrera (anticipado, víspera,
  día del evento), **entrega de kit** (víspera y día mismo, con lugar y hora), y de
  entrenamientos (a la hora, y un aviso de los que dejaste pendientes). Sin backend.

### 📅 Calendario
- Vista mensual con carreras y entrenamientos.

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
- Detalle de **solo lectura** (editar es explícito).

### ❤️ Condición (Apple Salud / HealthKit)
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
- **Récords personales** por distancia y velocidad promedio.
- Cards **educativas** por métrica (qué es, rangos por edad, tu valoración).

### 👤 Perfil
- Datos del usuario y **cierre de sesión**.
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
```

> **HealthKit no vive en Firestore.** VO₂max, HRV, FC, workouts y rutas se leen del
> dispositivo en cada sesión (nunca se suben). Lo único que persiste de Condición son los
> **check-ins** (`recoveryLogs`). Por eso Condición solo funciona en iPhone/Watch, no en Mac.

### Modelo de datos futuro (fases 1–4, tentativo)

Boceto para que las fases de la visión se implementen con estructura consistente. Todo cuelga
de `users/{uid}/…` y hereda las mismas reglas de seguridad. **Aún no existe** — es guía de diseño.

```
users/{uid}/goals/{goalId}          # ✅ fase 1 (ya existe): tipo, targetValue, startValue, distance, deadline
users/{uid}/plan/{planId}           # plantilla del plan (semanas, días)                       (fase 2)
users/{uid}/plan/{planId}/days/{d}  # día planificado: tipo, descripción (p. ej. 8×1'/2')       (fase 2)
users/{uid}/bodyLogs/{yyyy-MM-dd}   # review: peso, cintura, energía, hambre, fotos(ref)        (fase 3)
users/{uid}/nutrition/{profileId}   # objetivos: kcal, macros, hidratación; adherencia diaria   (fase 4)
```

Notas: la **adherencia** del plan (fase 2) sale de cruzar el día planificado con las
`TrainingSession.completed` que ya importa Salud; el **review corporal** (fase 3) reusa el patrón
de `recoveryLogs`; la **nutrición** (fase 4) se acota a *objetivos + adherencia (checkbox)*, no a
un registro de alimentos.

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
- `Presentation/Root/MainTabView.swift` — **dueño de todos los ViewModels**; monta los 5 tabs, arranca
  los streams de Firestore (`.task { … start() }`) y los observadores de Salud (`HKObserverQuery`).

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

### Dominio (`Domain/Entities/`) — sustantivos clave
- **Carreras**: `Race`, `RaceDiscipline` (5/10/15/21/42K, Trail, Otra), `RaceStatus`, `RaceReadiness`.
- **Entrenamiento**: `TrainingSession` + `TrainingType` (Carrera/CrossFit/Caminata/Senderismo/Otro),
  `HealthWorkout` (lo que se lee de Salud antes de importar). Ojo: `effortMinutes` (duración×RPE/5) y
  `sessionLoad` (RPE×min) viven en `TrainingSession`.
- **Condición**: `RecoverySnapshot`/`RecoveryEstimate`/`RecoveryTrend` (`Recovery.swift`),
  `RecoveryCheckIn`, `RecoveryCalibration`, `WorkloadInput`/`WorkloadRatio`/`WorkloadZone`
  (`Workload.swift`), `FitnessSummary`, `FitnessTrend`, `WorkoutRoute`, `RaceWeather`.
- **Otros**: `AppUser`, `UserProfile`, `ReminderPreferences`, `CalendarEvent`.

### Casos de uso (`Domain/UseCases/`)
Uno por responsabilidad (SRP), agrupados por archivo (`HealthUseCases.swift`, `RaceUseCases.swift`,
`TrainingUseCases.swift`, `AuthUseCases.swift`, …). Patrón: `Fetch*` (lee del repo) y `Assess*`/`Compute*`
(lógica pura). Los de carga/condición: `FetchRecovery`/`AssessRecovery`, `FetchWorkload`/`AssessWorkload`,
`AssessReadiness`, `ComputeTrainingLoad`, `FetchFitnessSummary`/`FetchFitnessTrend`.

### Data (`Data/`)
- **Repos** `Firestore*Repository` implementan los protocolos de `Domain/Repositories`.
- **Services**: `HealthKitService` (todas las queries de Salud), `EventKitService` (Calendario),
  `OpenMeteoService` (clima REST), `LocalNotificationService`, `GoogleSignInService`.
- **DTOs** en `Data/DTO` mapean Firestore ↔ entidades.

### Core (`Core/`)
Transversal: `Theme/Neon.swift` (paleta adaptable claro/oscuro), fuentes (`.mCaption`, `.mTitle3`…),
`Haptics`, `Log`. **Todo cambio de color/tipografía va aquí** para que aplique a toda la app.

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
- **Paleta `Neon`** (`Core/Theme/Neon.swift`): valores del **RunCalendar UI Kit** — `accent`
  `#3D8BFF`, `green` `#34D399` (esmeralda), `teal` `#2DD4CE`, `orange` `#FF9F45`, `purple`
  `#A78BFA`, `pink` `#FF6FA8`, `gold` `#FFD166` (dark, identidad insignia) + variantes `light`
  armonizadas. Degradados `buttonGradient` (azul→púrpura) y `logoGradient` (arcoíris de branding).
  **Cambia aquí y se propaga a toda la app.** Superficies del Kit (`Neon.background`/`surface`/
  `surfaceElevated`, dark-first, adaptables). El cuerpo usa SF en vez de Inter (nativo, cero peso).
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
| `RecoveryAccuracyChart` / `*TrendChart` | `Presentation/Health` | Gráficas interactivas (`chartXSelection`) |
| chips (`chip(...)`) | Detalle de carrera/entreno | Etiquetas de estado (Completado, Prioritario) |
| `Haptics` | `Core/Utils` | Feedback al guardar/confirmar |

### Patrones de interacción

- **Listas** como base; **pull-to-refresh** para recargar (carreras, entrenamientos).
- **Swipe actions** (eliminar / marcar hecho) en filas.
- **Sheets** para formularios de alta/edición; **`confirmationDialog`** para duplicados/decisiones.
- **Cards descartables** para avisos no bloqueantes (ver `RPEPromptCard`).
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
- **No hay target de tests**: la verificación es `xcodebuild … build` (BUILD SUCCEEDED) + correr la app.
  No intentes `xcodebuild test` ni asumas un suite; la lógica no trivial deja un check propio si aplica.
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
La base de métricas fiables ya existe; falta la estructura (objetivos, plan, nutrición) sobre la que
la IA pueda razonar — por eso la IA es la **última** fase, no la primera.

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
| **2. Review dominical** | Check-in semanal (peso, cintura, energía, hambre, fotos) al estilo del Manual | **Victoria temprana**: reusa el patrón de check-ins (`recoveryLogs`); gancho de hábito alto |
| **3. Plan + Campañas** | Plantilla semanal recurrente (Mar/Jue/Dom + técnica) → **misiones** de la Campaña; el import de Salud marca adherencia (planificado vs. `completed`) | Habilita el modelo de "Campañas" y responde "¿qué hago hoy?" |
| **4. Nutrición** | **Solo objetivos + adherencia (checkbox)**: macros/kcal objetivo, hidratación, ¿cumpliste hoy? — **no** food-logger | Dominio nuevo; acotado a propósito para no volverse contador de calorías |
| **5. IA + reportes** | Claude API razona sobre 1–4 → plan/reporte tipo Manual; entrega por correo | Requiere backend (Firebase Functions); **la API key vive en el backend, nunca en la app** |

> **Reestructura UX asociada:** pasar de tabs por *tipo de dato* (Carreras/Calendario/Entrenar/Condición)
> a tabs por *ciclo del atleta*: **Objetivos → Plan → Hoy → Progreso** (las 4 preguntas). La Fase 1 la habilita.
>
> **Rediseño visual (transversal, en curso):** de "formulario" a "misión" — número héroe, "faltan X días",
> Coach Insight, confianza cualitativa, cards reutilizables. Empieza por **Objetivos** y se rueda al resto.
> Detalle y patrones en [Diseño / UI → Dirección de rediseño](#dirección-de-rediseño-en-curso).
>
> Boceto de colecciones para estas fases: ver [Modelo de datos futuro](#modelo-de-datos-futuro-fases-1-4-tentativo).

**Hecho** (resumen): importación auto de Salud (todos los tipos, incl. "Otro") + rutas + splits,
búsqueda de ubicación + "Cómo llegar", Condición completa (recuperación, ACWR, VO₂max, tendencias,
PRs), readiness por carrera, RPE por sesión + esfuerzo del Watch, calibración **segmentada**
(por HRV/sueño/carga), **carga de recuperación/ACWR ponderada por RPE**, distancia 15K,
caminata/senderismo, recordatorios locales (carreras, kit con lugar/hora, entrenamientos + pendientes),
exportar carreras/kit al Calendario (EventKit, con coordenadas/URL/alarma).

**Pendiente:**

- [ ] **Widget de cuenta regresiva** (WidgetKit) — espera membresía de pago (App Groups).
- [ ] Target de **Apple Watch** (watchOS).
- [ ] **Catálogo de carreras** compartido entre usuarios.
