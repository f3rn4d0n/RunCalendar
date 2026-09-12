# Fase 4 · Registro de fuerza + PR de levantamiento

> **Plan de implementación, escrito antes de tocar código.** Nada de lo que describe existe
> todavía. Se redactó con la exploración del repo ya hecha, así que las rutas, líneas y patrones
> a espejar están verificados contra el código de ese momento — si algo no cuadra al implementar,
> gana el código, no este documento.
>
> Borrar este archivo cuando la fase esté cerrada y lo que quede viva en `docs/pendientes.md`.

## Context

`docs/pendientes.md` (P3) llama al registro de fuerza *"la mitad híbrida del producto, y hoy no
existe"* y *"la brecha más grande entre lo que el producto promete y lo que hace: hoy solo sirve a
corredores"*. Estaba bloqueado por "conviene meterlo con el target de pruebas ya montado" — ese
bloqueador **ya no aplica** (P1 completo).

Lo que la exploración encontró y cambia el planteamiento:

1. **La sesión de gimnasio ya existe.** `TrainingType.crossfit` (icono `dumbbell.fill`,
   `tracksDistance: false`) ya se registra a mano y **HealthKit ya la importa**
   (`HealthKitService.swift:705-717` mapea `traditionalStrengthTraining`/`functionalStrengthTraining`
   → `.crossfit`). Ya cuenta para `sessionLoad`, ACWR y recuperación. Falta **solo** el detalle
   (ejercicio × peso × reps) y el récord.
2. **HealthKit no da series/reps/peso.** No existe API para eso. El registro es necesariamente
   manual; de Salud se hereda duración, FC y effort score del workout contenedor.
3. **Los récords no viven en Progreso.** Viven en `PersonalRecordsView`, un sheet desde el `medal`
   del toolbar de `TrainingListView`. El patrón a espejar es
   `BestSplit` (entidad tonta + algoritmo puro) + `PersonalRecords` (namespace-enum que normaliza,
   deduplica y rankea) + `PersonalRecordsView` (List con número héroe y `DisclosureGroup`).
4. **`PersonalRecords` rankea por ritmo normalizado, no por tiempo bruto.** El análogo exacto en
   fuerza es rankear por **1RM estimado**, no por peso bruto: así 100 kg × 3 compite con 110 kg × 1.

## Decisiones tomadas con Fernando

| Decisión | Elegido | Por qué |
|---|---|---|
| Dónde viven las series | **Campo `sets: [StrengthSet]` en `TrainingSession`** | La sesión ya existe, ya se importa y ya cuenta para la carga. Una colección `strength/` aparte duplicaría la sesión y partiría en dos la carga del mismo día. Hay que **corregir el boceto de `README.md:489`** que proponía lo contrario. |
| Alcance | **Solo registro + PR** | Fuera: meta de fuerza y días de fuerza en el plan (ver abajo). |
| Nombre del ejercicio | **Enum fijo cerrado**, sin caso `.otro` | Un `.otro` sería un bucket de récord que mezcla curl con encogimientos y produce un PR sin sentido. Lo que no esté cae en `wod`/`notas` como hoy. |
| Peso corporal | **Dentro, con lastre + récord por reps** | Dominadas y fondos son pan de CrossFit. `weightKg` es el **lastre añadido** (0 = sin lastre) y su récord se mide **por repeticiones**. |

### Explícitamente fuera de alcance

- **`GoalType.liftPR` (meta de fuerza).** Cuesta 5 switches exhaustivos en `Goal.swift` + el
  problema del qualifier (hoy `distance: RaceDiscipline?` sirve solo a `raceTime`; fuerza necesita
  *otro* discriminador) + `Recommend`/`Pace`/`Confidence`. Y sin historial de levantamientos no hay
  de dónde sacar "valor actual" ni recomendación. Se añade cuando haya datos que la sostengan.
- **Días de fuerza en el plan.** `PlannedWorkoutKind` es 100% de carrera y la lógica 80/20 no sabe
  de fuerza. Además `docs/motor-de-entrenamiento.md` advierte: *"dos mecanismos para lo mismo
  obligan a decidir cuál manda"* — habría que decidir si compite con `daysPerWeek`.
- **Importar series de Salud.** HealthKit no las expone. La sesión sigue llegando con `sets: []`.

---

## 1. Dominio

### Archivo nuevo: `RunCalendar/Domain/Entities/StrengthSet.swift`

Enum + struct en un archivo, igual que `TrainingSession.swift` aloja `TrainingType` + `TrainingSession`.

**`enum LoadStyle: Sendable`** — `case external, bodyweight`. Es lo que decide cómo se rankea el
récord y qué significa `weightKg`.

**`enum StrengthExercise: String, CaseIterable, Identifiable, Sendable`** — rawValue en español,
`id`, `displayName`, `systemImage`, `loadStyle`. 14 casos:

| Grupo | Casos (rawValue) |
|---|---|
| **Carga externa** (12) | Sentadilla · Sentadilla frontal · Peso muerto · Peso muerto rumano · Hip thrust · Press de banca · Press militar · Remo con barra · Cargada · Arranque · Envión · Thruster |
| **Peso corporal** (2) | Dominada · Fondo |

`systemImage`: usar **solo** símbolos verificados en iOS 18 —
`figure.strengthtraining.traditional` (sentadillas, peso muerto, hip thrust, press, remo),
`figure.strengthtraining.functional` (cargada, arranque, envión, thruster, dominada, fondo).
Repetir símbolo entre casos es correcto; inventar nombres de SF Symbols que no existen, no.

`// ponytail:` requerido en el enum: catálogo cerrado de 14; lo que falte se añade al enum en un
release, no con un caso `.otro` que arruinaría el ranking.

**`struct StrengthSet: Identifiable, Equatable, Sendable`**

```swift
let id: String                  // UUID, igual que CampaignMission
var exercise: StrengthExercise
var weightKg: Double            // carga total (external) | lastre añadido (bodyweight), 0 = sin lastre
var reps: Int
```

Derivados en la entidad (normalizaciones por esfuerzo, no políticas de ranking — el mismo papel que
`RunEffort.paceSecondsPerKm`):

- `var volumeKg: Double { weightKg * Double(reps) }`
- `var estimatedOneRM: Double?` — **solo para `.external`**; `nil` en `.bodyweight` (estimar un 1RM
  de dominadas exigiría el peso corporal del atleta y eso es un dato inventado).
  - Fórmula **Epley**: `weightKg * (1 + Double(reps) / 30)`.
  - `nil` si `weightKg <= 0` o `reps <= 0`.
  - **Caso especial obligatorio: `reps == 1` devuelve `weightKg` tal cual.** Epley crudo daría
    `1.033 × peso` para una single, o sea inventaría 3 kg que nadie levantó. Es el bug silencioso
    más probable de toda la fase.
  - `// ponytail:` Epley sin calibrar contra nadie. Elegida sobre Brzycki porque es lineal, no se
    rompe cerca de 30 reps, y es la que usan Strong/Hevy — la que el atleta ya vio en otra app.

### Cambio en `RunCalendar/Domain/Entities/TrainingSession.swift`

1. Campo nuevo en la zona "Específicos de CrossFit", junto a `wod` (línea ~19):
   `var sets: [StrengthSet]`, con comentario de **por qué vive aquí y no en `strength/`**.
2. Parámetro `sets: [StrengthSet] = []` en el init explícito (línea 76-110), **justo después de
   `wod:`**. Verificado: hay init explícito con todos los parámetros con default y los 23 call
   sites usan argumentos con etiqueta → **ninguno se rompe**.
3. Un solo derivado nuevo:
   `var strengthVolumeKg: Double? { sets.isEmpty ? nil : sets.reduce(0) { $0 + $1.volumeKg } }`
   — el "distanceKm del gimnasio". **No** añadir `totalReps`/`bestSet`/`volumePorEjercicio`: nadie
   los consume. Documentar que las series de peso corporal sin lastre suman 0 (no conocemos el peso
   del atleta, y meterlo sería inventar).

**No tocar** `sessionLoad` ni `effortMinutes`: la carga sigue siendo RPE × minutos. Meter kg ahí
cambiaría ACWR y recuperación sin calibración detrás.

---

## 2. Persistencia — `RunCalendar/Data/DTO/TrainingDTO.swift`

Espejo literal de `Goal.manualMissions` en `RunCalendar/Data/DTO/GoalDTO.swift` (helpers privados
`missionToFirestore`/`missionFromFirestore` + array de diccionarios). Misma colección
`users/{uid}/trainings/{id}`, **sin cambios en reglas de seguridad ni en el repositorio**.

```
sets: [ { id: "uuid", exercise: "Sentadilla", weightKg: 100.0, reps: 5 }, … ]
```

Cuatro detalles que no son obvios y que hay que respetar:

1. **`dict["sets"] = session.sets.map(setToFirestore)` sin condicional.** Con `setData(merge: true)`
   los arreglos se reemplazan enteros, pero **solo si la clave viaja**. Si se escribiera
   `session.sets.isEmpty ? nil : …`, borrar la última serie no borraría nada en Firestore.
2. **Decodificar el peso como `NSNumber`**: `(data["weightKg"] as? NSNumber)?.doubleValue ?? 0`.
   Un `100` escrito a mano en la consola de Firebase vuelve como `Int` y `as? Double` falla en
   silencio. (`GoalDTO.targetValue` tiene hoy esa misma exposición — **no la arregles ahí**, fuera
   de alcance; solo no la repitas.)
3. **Guard sobre `id` + `exercise`** en `setFromFirestore`: un ejercicio desconocido (renombrado a
   futuro) descarta esa serie, no tumba la sesión entera. Igual que `missionFromFirestore`.
4. Tamaño: 100 series ≈ 10 KB contra el límite de 1 MiB por documento. No es problema.

---

## 3. Récords de levantamiento

### Archivo nuevo: `RunCalendar/Presentation/Training/LiftRecords.swift`

Vive en `Training/` (no en `Races/`) por simetría: `PersonalRecords` está en `Races/` porque su
fuente principal son carreras; esta solo lee sesiones.

```swift
struct LiftEffort: Identifiable {
    let id: String            // "\(sessionID)-\(set.id)"
    let date: Date
    let sessionTitle: String
    let set: StrengthSet
}

struct LiftRecord: Identifiable {
    let exercise: StrengthExercise
    let best: LiftEffort
    let history: [LiftEffort]    // cronológico ascendente
    var id: String { exercise.id }
}

enum LiftRecords {
    static let maxRepsForEstimate = 12
    static func compute(sessions: [TrainingSession]) -> [LiftRecord]
}
```

**Algoritmo:**

1. **Qué es un esfuerzo**: una serie de una sesión con `completed == true` y `reps > 0`.
   - El filtro `completed` es nuevo respecto a `PersonalRecords` (que no lo necesita porque las
     corridas llegan de Salud siempre completadas). **Sin él, una sesión de gimnasio planeada a
     futuro con series escritas generaría un PR que nadie levantó.**
2. **Agrupar por `exercise`** (`Dictionary(grouping:)`).
3. **Rankear según `exercise.loadStyle`** — esta es la parte con criterio:
   - **`.external`** → por `estimatedOneRM`, descartando series con `reps > maxRepsForEstimate`.
     `// ponytail:` 12 reps: Epley sobreestima fuerte arriba de ~10–12 y un AMRAP de 20 fabricaría
     un PR falso. Esas series **siguen registradas y cuentan para volumen**, solo no compiten.
   - **`.bodyweight`** → por `(reps, weightKg)`: primero más repeticiones, y a igualdad de reps,
     más lastre. **Sin tope de reps** (una serie de 30 dominadas *es* el récord).
     `// ponytail:` criterio único; si alguien entrena dominada lastrada pesada, esto hay que
     partirlo en dos récords (más reps / más lastre) en vez de ordenarlos en un solo eje.
4. **Deduplicar por sesión**: del grupo, quedarse con el mejor esfuerzo de **cada sesión**. Misma
   razón que la dedup de `PersonalRecords`: cinco series de calentamiento de sentadilla no son cinco
   récords, y la progresión se vuelve ilegible si lo son.
5. **Récord** = el máximo; **historial** = los esfuerzos deduplicados por fecha ascendente.
6. Devolver solo ejercicios **con al menos un esfuerzo**, en el orden de
   `StrengthExercise.allCases`. Nada de 14 secciones vacías.

### Archivo nuevo: `RunCalendar/Presentation/Training/LiftRecordsView.swift`

Copia estructural de `RunCalendar/Presentation/Races/PersonalRecordsView.swift`, **sin** el estado
de carga (aquí no hay consulta a Salud: todo es local y síncrono) y **sin** el `sourceBadge` (una
sola fuente: el registro manual).

- `NavigationStack > List`, `navigationTitle("Récords de fuerza")`, `.inline`, `Button("Cerrar")`.
- Recibe `let trainingViewModel: TrainingViewModel`;
  `private var records: [LiftRecord] { LiftRecords.compute(sessions: trainingViewModel.sessions) }`.
- Vacío: `EmptyStateView(icon: "dumbbell", title: "Sin récords de fuerza", message: "Registra las
  series de un entrenamiento de CrossFit —ejercicio, peso y repeticiones— y aquí verás tu mejor
  levantamiento estimado.")` (`EmptyStateView` ya existe).
- Una `Section(exercise.displayName)` por récord, con número héroe según el estilo:
  - `.external` → `"\(Goal.trim(oneRM)) kg"`, subtítulo `"1RM estimado · \(peso) kg × \(reps)"`.
  - `.bodyweight` → `"\(reps) reps"`, subtítulo `"sin lastre"` o `"+\(Goal.trim(peso)) kg"`.
  - Estilo: `.font(.mLargeTitle.bold()).monospacedDigit()`, `medal.fill` en `Neon.gold` a la
    derecha, fila de contexto con título de sesión + `date.mediumString()`,
    `DisclosureGroup("Progresión · N esfuerzos")` con el historial invertido cuando hay más de uno.
- **La palabra "estimado" siempre visible** en los de carga externa: es un número derivado de una
  fórmula sin calibrar, y presentarlo como "tu 1RM" sería justo el dato inventado que el repo se
  prohíbe.

---

## 4. UI de captura y lectura

### `RunCalendar/Presentation/Training/TrainingFormView.swift`

Punto de inserción: la rama `else` de `if type.tracksDistance` (línea ~84), que hoy es solo
`Section("CrossFit") { TextField("WOD", …) }`. Se le añade una `Section("Series")` hermana.

1. `@State private var sets: [StrengthSet] = []` junto a los demás `@State`.
2. En `populate(from:)`: `sets = session.sets`.
3. En `save()`: `sets: type.tracksDistance ? [] : sets` — el mismo gateo que ya hacen `wod` y
   `distanceKm`, para que cambiar de CrossFit a Carrera no deje series huérfanas.
4. Edición **inline con bindings** (`ForEach($sets) { $set in … }`), sin hoja aparte de "agregar
   serie": `Picker` de ejercicio con `.labelsHidden()`, `TextField(value:format: .number)` para kg
   y reps, `.onDelete { sets.remove(atOffsets:) }`, y un `Button` "Agregar serie".
   - Usar `TextField(value:format: .number)` en vez del patrón `String` + `Double(texto)` de
     `distanceText`: menos líneas y resuelve la coma decimal por locale sin `replacingOccurrences`.
   - **`addSet()` hereda ejercicio y peso de la serie anterior.** Una línea, y es la diferencia
     entre registrar 5 series y abandonar en la segunda.
   - La etiqueta del campo de peso cambia con `loadStyle`: `"kg"` en carga externa, `"lastre"` en
     peso corporal. Sin eso, `weightKg` significa dos cosas y nadie lo sabe.
   - **Sin `.onMove`, sin validación de rango, sin duplicar serie.** YAGNI.
   - `ForEach($sets)` exige que el `id` de `StrengthSet` sea estable (`let`, generado al crear, no
     derivado del contenido).
5. No cambia la condición de `.disabled` del botón Guardar (sigue siendo solo el título).

### `RunCalendar/Presentation/Training/TrainingDetailView.swift`

En la rama `else` de `if session.type.tracksDistance` (línea ~90). Reusa el helper
`row(_:_:icon:)` que ya existe:

```swift
if !session.sets.isEmpty {
    Section("Series") {
        ForEach(session.sets) { set in
            row(set.exercise.displayName, "\(Goal.trim(set.weightKg)) kg × \(set.reps)",
                icon: set.exercise.systemImage)
        }
        if let volume = session.strengthVolumeKg {
            row("Volumen total", "\(Goal.trim(volume)) kg", icon: "scalemass")
        }
    }
}
if let wod = session.wod, !wod.isEmpty { Section("WOD") { Text(wod) } }
```

**`wod` se conserva**: series y texto libre conviven — el WOD describe el formato ("5 rondas por
tiempo") y las series el hierro.

### Entrada a los récords — `RunCalendar/Presentation/Training/TrainingListView.swift`

Segundo botón de toolbar junto al `medal` existente (línea ~106): `Image(systemName: "dumbbell")`,
`accessibilityLabel("Récords de fuerza")`, `@State private var showingLiftRecords` + `.sheet`.

`// ponytail:` dos botones de récords en el toolbar; si se llena, fusionar ambas pantallas bajo
"Récords" con un Picker segmentado Carrera/Fuerza. Se elige esto ahora porque no toca
`PersonalRecordsView` (que ya carga splits de Salud y tiene tres estados por sección) y el diff
cabe en 6 líneas.

**No se añade evento de `Usage`.** `Usage.sessionCompleted(type:)` ya cuenta la sesión de CrossFit;
un `strengthLogged` no responde ninguna pregunta que alguien vaya a hacer todavía.

---

## 5. Tests — `RunCalendarTests/StrengthTests.swift` (archivo nuevo, dos suites)

Swift Testing, `@Suite`/`@Test`/`#expect`. Espeja `BestSplitTests` (algoritmo puro) y
`ManualMissionTests` (CRUD vía VM contra el spy del repo fake). Criterio de `RecoveryTests`:
**propiedades, no valores**, cuando la constante no está calibrada.

### `@Suite("LiftRecords · propiedades del ranking")`

| Caso | Tipo | Qué afirma |
|---|---|---|
| `singleRepIsExactlyTheWeight` | valor | 1 rep → `estimatedOneRM == weightKg`. Definicional: vale para Epley, Brzycki y cualquier fórmula honesta. |
| `moreWeightSameRepsNeverRanksLower` | propiedad | monotonía en peso. |
| `moreRepsSameWeightNeverRanksLower` | propiedad | monotonía en reps. |
| `moreRepsCanBeatMoreWeight` | propiedad | el corazón de la fase: existe (peso alto × 1) vs (peso menor × varias) donde gana el segundo. Sin fijar números. |
| `bestIsTheMaxOfTheHistory` | propiedad | invariante del ranking; se rompe solo si miente, no si se recalibra. |
| `exercisesDoNotMix` | estructura | sentadilla y peso muerto en la misma sesión → dos récords. |
| `incompleteSessionsDoNotCount` | estructura | sesión futura/no completada con un levantamiento enorme → sin récord. |
| `historyHasOneEffortPerSessionChronological` | estructura | 5 series del mismo ejercicio en una sesión → 1 esfuerzo, historial ascendente. |
| `highRepSetsNeverSetARecordInExternalLifts` | propiedad | `reps > 12` en sentadilla no gana récord aunque su Epley crudo sea el mayor. |
| `bodyweightRanksByRepsThenLoad` | propiedad | 12 dominadas > 8 dominadas; y a 12 iguales, gana la que lleva lastre. |
| `bodyweightHasNoOneRMEstimate` | valor | `estimatedOneRM == nil` en dominada/fondo. |
| `highRepBodyweightStillCounts` | propiedad | 30 dominadas **sí** es récord (el tope de 12 es solo de carga externa). |
| `zeroWeightOrRepsProducesNoEffort` | borde | sin crash, sin esfuerzo. |
| `noStrengthSessionsMeansNoRecords` | borde | solo carreras → `[]`. |

### `@Suite("Fuerza · registro") @MainActor`

| Caso | Tipo | Qué afirma |
|---|---|---|
| `savingSessionSendsSetsToRepo` | estructura | `TestApp` + `training.save(…)` → `trainingRepo.updated.last?.sets` intacto. |
| `dtoRoundTripKeepsSets` | valor | `toDomain(toFirestore(session))` conserva id/ejercicio/peso/reps. Factible sin Firestore vivo. |
| `dtoWritesEmptyArrayNotNil` | valor | `toFirestore(sesión sin series)["sets"]` es `[]`, **no** `nil`. Es el test que protege "borrar la última serie sí se borra" bajo `merge: true`. |
| `dtoDropsUnknownExercise` | borde | `exercise: "Zancada lunar"` se descarta; las demás series sobreviven. |
| `strengthVolumeIsTheSumOfSets` | valor | suma correcta; `nil` sin series. |

**No se prueba** la UI (el repo no tiene tests de vistas) ni `FirestoreTrainingRepository` (necesita
Firebase vivo).

---

## 6. Orden de ejecución

**Paso 0 — hecho.** Este documento vive en `docs/plan-fuerza.md` y el issue de seguimiento es el
**#278** (regla del repo: todo PR parte de un issue). El último PR de abajo lo cierra con
`Closes #278`.

**Commit/PR 1 — dominio + persistencia + captura.** `StrengthSet.swift` (nuevo),
`TrainingSession.swift`, `TrainingDTO.swift`, `TrainingFormView.swift`, `TrainingDetailView.swift`,
y la suite "Fuerza · registro". **Ya es entregable solo**: registrar y leer series tiene valor sin
récords.

**Commit/PR 2 — récords.** `LiftRecords.swift`, `LiftRecordsView.swift`, el botón en
`TrainingListView.swift`, la suite "LiftRecords · propiedades".

**Commit/PR 3 — docs.**
- `README.md:489`: **borrar** `users/{uid}/strength/{sessionId}` del boceto futuro, con nota de por
  qué no existió (las series viven en la sesión que ya cuenta para la carga).
- `README.md` ~455 (modelo de datos actual): `trainings/{id}` menciona las series de fuerza.
- `README.md:794`: Fase 4 → ✅ con alcance explícito (registro + PR; meta de fuerza y días de
  fuerza en el plan, pendientes).
- `docs/pendientes.md:411` y la nota `:422`: marcar resuelto el registro, dejar lo que queda.
- `docs/pendientes.md` ~400 ("Umbrales sin calibrar"): añadir **Epley** y el **tope de 12 reps**,
  que es donde el repo promete que viven las constantes no comprobadas.
- `docs/pendientes.md`: entrada nueva de **deuda de producto** — `docs/ejemplo-manual-atleta.md`,
  el norte de diseño, **no menciona fuerza en absoluto** (lo más cercano son unos lunges dentro de
  la sesión de técnica de carrera). No inventes esa sección: regístrala como hueco. El manual
  describe a un corredor y la app ya no lo es.

### Qué NO tocar
`TrainingType` (nada de un caso `.strength`: el gimnasio es `.crossfit` y así se importa de Salud) ·
`sessionLoad`/`effortMinutes`/ACWR/recuperación · `HealthKitService` e `importWorkout` · `GoalType` y
todo `Presentation/Goals` · `GeneratePlanUseCase` · `PersonalRecords` y `PersonalRecordsView` · las
reglas de seguridad de Firestore · el campo `wod` · `RunCalendar/Resources/RunCalendar.entitlements`
(Fernando lo tiene modificado en local a propósito, sin commitear, porque no tiene cuenta de pago).

---

## 7. Verificación

1. `xcodegen generate` tras cada commit que añada archivos (las fuentes se recogen por carpeta).
2. `xcodebuild build -scheme RunCalendar -destination 'id=<sim>' CODE_SIGNING_ALLOWED=NO`.
3. `xcodebuild test -scheme RunCalendar -destination 'id=<sim>' CODE_SIGNING_ALLOWED=NO` — las dos
   suites nuevas y **ninguna regresión** en las 22 existentes.
4. **Prueba manual en dispositivo** (memoria `ui-needs-device-review`; además hay dos riesgos que
   los tests no cubren):
   - Registrar una sesión de CrossFit con 3 series → cerrar y reabrir la app → siguen ahí.
   - **Borrar la última serie → recargar → confirmar que no volvió** (es el riesgo de `merge: true`
     con arreglos).
   - Registrar 12 dominadas y 8 con +10 kg → el récord de Dominada dice "12 reps".
5. CI verde antes de mergear (el check es requerido). Ojo con la fragilidad de zona horaria ya
   conocida: el runner corre en UTC y la máquina local no.

## 8. Riesgos y huecos conocidos

1. **Epley sin calibrar** presentado como número grande en pantalla. Mitigado por la palabra
   "estimado" y el `ponytail:`, pero es exactamente lo que `docs/pendientes.md` promete recalibrar
   con usuarios reales.
2. **Tope de 12 reps invisible**: un AMRAP de 20 sentadillas quedará registrado pero no saldrá en
   récords. Considerar una línea de copy en la vista que lo explique.
3. **`weightKg` significa dos cosas** (carga total vs. lastre) según `loadStyle`. La etiqueta del
   campo en el formulario es lo único que lo desambigua — no la omitas.
4. **Volumen en kg ignora el peso corporal**: 30 dominadas sin lastre suman 0 kg de volumen. Es
   honesto (no conocemos el peso del atleta en el momento de la serie) pero puede sorprender.
5. **Una sola sesión de fuerza por día** antes de que el dedup de import de Salud colisione
   (`isSameActivity` sin distancia compara solo día+tipo; ya marcado con `ponytail:` en
   `TrainingViewModel:200`). No lo arregla esta fase.
6. **Unilaterales / peso por lado** no se modelan; el peso es el total de la barra. Ningún ejercicio
   del catálogo propuesto es unilateral, así que hoy no muerde.
7. **El norte de diseño no cubre fuerza** (`ejemplo-manual-atleta.md`). Esta fase se diseñó sin
   requisitos de producto escritos; conviene extender el manual antes de la Fase 5 (IA), que
   razonará sobre "objetivos + plan + adherencia + condición (y fuerza, si ya existe)".
