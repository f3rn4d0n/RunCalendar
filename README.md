# RunCalendar 🏃‍♂️

App para iPhone y Mac que reúne tu **calendario de carreras** (ubicación, costos, entrega de
kits, fecha) y tu **programa de entrenamiento** (CrossFit y carrera), con login.

Construida con **SwiftUI**, **Clean Architecture**, **SOLID** y **Firebase** (Auth + Firestore).

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
   - **Authentication → Sign-in method →** Email/Password **y** Apple.
   - **Firestore Database →** crea la base en modo producción.

### 3. Configurar Sign in with Apple

1. En `project.yml`, pon tu **`DEVELOPMENT_TEAM`** (Team ID de Apple Developer) y
   vuelve a correr `xcodegen generate`. (O selecciónalo en Xcode → Signing & Capabilities.)
2. La capability **Sign in with Apple** ya está declarada en
   `RunCalendar/Resources/RunCalendar.entitlements`.
3. En Firebase, en el proveedor **Apple**, configura el **Service ID** / OAuth según la
   [guía oficial](https://firebase.google.com/docs/auth/ios/apple).

### 4. Reglas de seguridad de Firestore

Cada usuario solo accede a sus propios datos. Pega esto en **Firestore → Reglas**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. Compilar y correr

- **iPhone:** elige un simulador o tu dispositivo y ⌘R.
- **Mac:** en el selector de destino elige **My Mac (Designed for iPad)** y ⌘R.

---

## Modelo de datos (Firestore)

```
users/{uid}                     # perfil
users/{uid}/races/{raceId}      # carreras
users/{uid}/trainings/{id}      # entrenamientos (CrossFit / carrera)
```

---

## Estructura de carpetas

```
RunCalendar/
├── App/            # @main, AppDelegate (Firebase), RootView, DI/AppContainer
├── Core/           # utilidades, componentes y extensiones reutilizables
├── Domain/         # Entities · Repositories (protocolos) · UseCases
├── Data/           # DTO · Repositories (implementaciones Firebase)
├── Presentation/   # Auth · Races · Training · Calendar · Root (vistas + ViewModels)
└── Resources/      # Assets, entitlements, GoogleService-Info.plist (lo pones tú)
```

---

## Roadmap (fases siguientes)

- [ ] Target de **Apple Watch** (watchOS)
- [ ] Notificaciones / recordatorios de carreras y entrega de kits
- [ ] Mapa embebido en el detalle de la carrera
- [ ] Catálogo de carreras compartido entre usuarios
- [ ] Sincronización con Apple Health / Apple Calendar
```
