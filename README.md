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
