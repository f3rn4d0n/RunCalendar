# RunCalendar 🏃‍♂️

App para iPhone y Mac que reúne tu **calendario de carreras** (ubicación, costos, entrega de
kits, fecha), tu **programa de entrenamiento** (CrossFit y carrera) y tu **condición física**
(recuperación, carga y forma leídas de Apple Salud), con login.

Construida con **SwiftUI**, **Clean Architecture**, **SOLID** y **Firebase** (Auth + Firestore).

> **¿Eres otra IA o dev retomando el proyecto?** Empieza por [Funcionalidades](#funcionalidades)
> (qué existe hoy), luego [Notas para desarrolladores](#notas-para-desarrolladores--ia)
> (convenciones y trampas) y [Troubleshooting](#troubleshooting). El [Roadmap](#roadmap-y-backlog)
> tiene lo pendiente.

---

## Funcionalidades

Cuatro pestañas: **Carreras**, **Calendario**, **Entrenar** y **Condición**.

### 🏁 Carreras
- Alta/edición de carreras: nombre, fecha, costo, entrega de kit, prioridad.
- **Ubicación con búsqueda** (MapKit `MKLocalSearch`): busca por nombre, dirección o
  `lat,long`; vista previa en mapa; recuerda el texto previo al editar.
- Botón **"Cómo llegar"** que abre Apple Maps, Google Maps o Waze.
- Detalle con **mapa de la ruta** (si la carrera se corrió y tiene GPS).
- **Readiness por carrera**: qué tan listo estás para cada distancia, consciente de la
  fecha (una 5K esta semana vs. una 42K la próxima).

### 📅 Calendario
- Vista mensual con carreras y entrenamientos.

### 🏋️ Entrenar
- Entrenamientos de **carrera** y **CrossFit** (WOD), con duración, distancia, ritmo objetivo.
- **Importación automática desde Apple Salud** al abrir la app (+ pull-to-refresh), con
  dedup (evita duplicar lo que ya registró el Apple Watch). Importa **todo el historial**.
- **Mapa de ruta** interactivo por entrenamiento: animación del recorrido, velocidad,
  ritmo cardiaco por zona, distancia, y **splits** por km. Clima del día del entreno.
- **RPE por sesión** (esfuerzo 1–10) + **carga de sesión** (RPE × minutos). El RPE se
  **lee automáticamente del Apple Watch** (`workoutEffortScore`, iOS 18+) al importar;
  las ya importadas se rellenan solas (backfill idempotente).
- Detalle de **solo lectura** (editar es explícito).

### ❤️ Condición (Apple Salud / HealthKit)
- **Resumen de forma**: VO₂max, FC en reposo, tendencia de fitness (Swift Charts interactivas).
- **Recuperación estimada** (orientativa, no médica): horas hasta estar recuperado a partir de
  **HRV (SDNN)**, **FC en reposo**, **carga reciente** y **sueño**.
- **Check-in diario** "¿cómo te sientes?" (1–5) + gráfica **"¿acierta el modelo?"**
  (sentido vs. predicho).
- **Calibración**: aprende el sesgo de tus check-ins y ajusta las horas de recuperación a
  tu cuerpo (se activa con ~2 semanas de registros).
- **Carga de entrenamiento (ACWR)**: ratio agudo:crónico con zonas (óptimo / riesgo).
- **Récords personales** por distancia y velocidad promedio.
- Cards **educativas** por métrica (qué es, rangos por edad, tu valoración).

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
users/{uid}/trainings/{id}           # entrenamientos (CrossFit / carrera; incluye rpe)
users/{uid}/recoveryLogs/{yyyy-MM-dd} # check-in diario de recuperación (para calibrar)
```

> **HealthKit no vive en Firestore.** VO₂max, HRV, FC, workouts y rutas se leen del
> dispositivo en cada sesión (nunca se suben). Lo único que persiste de Condición son los
> **check-ins** (`recoveryLogs`). Por eso Condición solo funciona en iPhone/Watch, no en Mac.

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
- **Puente RPE ↔ recuperación (pendiente conocido)**: hoy la carga de la recuperación/ACWR usa
  los **minutos de HealthKit**, no el `sessionLoad` (RPE × min) de las `TrainingSession`.
  Unir ambos requiere puentear `TrainingViewModel` → flujo de Salud; es el siguiente escalón
  natural de la calibración.

---

## Roadmap y backlog

**Hecho** (resumen): importación auto de Salud + rutas + splits, búsqueda de ubicación +
"Cómo llegar", Condición completa (recuperación, ACWR, VO₂max, tendencias, PRs), readiness por
carrera, RPE por sesión + esfuerzo del Watch + calibración.

**Pendiente:**

- [ ] **Puente RPE → recuperación/ACWR**: usar `sessionLoad` (RPE × min) como input de carga.
- [ ] **Calibración v2**: regresión sobre HRV/sueño/carga en vez de un factor de sesgo global.
- [ ] **Prompt activo de RPE** al abrir si un workout llegó sin esfuerzo del reloj.
- [ ] **Más tipos de entrenamiento** (hoy solo carrera y CrossFit).
- [ ] **Widget de cuenta regresiva** (WidgetKit) — espera membresía de pago (App Groups).
- [ ] Target de **Apple Watch** (watchOS).
- [ ] **Notificaciones / recordatorios** de carreras y entrega de kits.
- [ ] **Catálogo de carreras** compartido entre usuarios.
- [ ] Sincronización con **Apple Calendar** (EventKit).
