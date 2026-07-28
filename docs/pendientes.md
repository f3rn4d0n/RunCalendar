# Pendientes

> **Qué es este documento.** El backlog real de Rumbo, priorizado y con el *por qué* de cada
> prioridad. Vive aquí y no en el README para que el README cuente el producto y esto cuente el
> trabajo. La tabla de fases (la narrativa del producto) sigue en
> [Roadmap](../README.md#roadmap-y-backlog).
>
> Los atajos deliberados del código están marcados con `// ponytail:` y se listan con
> `/ponytail-debt`; aquí solo aparecen los que bloquean algo.

## Prioridades

| | Significado |
|---|---|
| **P0** | Está roto o da consejo incorrecto. Se arregla antes de seguir construyendo |
| **Bloqueado** | Depende de algo externo (una cuenta, un permiso). Fuera de la escala |
| **P1** | Bloquea tener usuarios reales o bloquea las fases siguientes |
| **P2** | Deuda con costo visible; se paga cuando toque el área |
| **P3** | Mejoras y extensiones. Sin fecha |

---

## P0 · Roto hoy

*Vacío.* Lo que estaba aquí:

- ~~**Sin modo lesión / enfermedad / descarga**~~ — resuelto: `WeekStatus` pausa la medición en vez
  de marcar 0% al atleta que no entrenó por gripe o lesión. Ver
  [adherencia.md](adherencia.md#semanas-que-no-se-miden).
- **Entitlement de Sign in with Apple** → movido a *Bloqueados* (abajo): no es un error del
  proyecto, falta la cuenta de Apple Developer.

---

## Bloqueados por dependencias externas

No entran en la escala de prioridad porque no dependen de nosotros.

### Sign in with Apple

`RunCalendar/Resources/RunCalendar.entitlements` no tiene `com.apple.developer.applesignin`, así que
el botón de `LoginView` (`AppleIconButton` → `AppleSignInController`) **compila y falla en runtime**
con error 1000.

**No se arregla restaurando el archivo.** Sin cuenta de pago en el Apple Developer Program no se
puede habilitar la capability en el App ID, y Xcode vuelve a quitar el entitlement al firmar. El
login por email/contraseña y Google sí funcionan, así que la app es usable mientras tanto.

Cuando exista la cuenta: habilitar *Sign in with Apple* en el App ID (§4 de la puesta en marcha del
README), restaurar el entitlement y verificar que Xcode ya no lo borre.

---

## P1 · Bloquea usuarios reales o las fases siguientes

### Observabilidad

Hoy solo hay `Log` (`os.log` por categorías: App, Auth, Races, Training, Profile, Health). Sirve
con el Mac conectado y **nada más**: en el teléfono de alguien más no hay forma de saber que algo
falló.

Con usuarios reales eso significa operar a ciegas: un crash en el import de Salud, un permiso que
se denegó, una escritura a Firestore que rebota — todo se ve igual desde aquí, o sea, no se ve.

Alcance propuesto, en orden:

1. ✅ **Crashlytics.** Hecho. `FirebaseCrashlytics` en el target, `Log.configureCrashReporting()`
   después de `FirebaseApp.configure()`, y subida de dSYM en un `postBuildScript` **solo en
   Release** (Debug no genera dSYM y ahí el reporte está apagado). `DEBUG_INFORMATION_FORMAT` se
   fija explícito en Release: sin dSYM los reportes llegan como direcciones de memoria.
2. ✅ **Errores no fatales en los caminos frágiles.** Hecho vía `Logger.failure(_:_:)`, que escribe
   al log del sistema **y** a Crashlytics. Los 10 `catch` que había se convirtieron: autorización y
   escritura de HealthKit, traza GPS, clima (carrera y entrenamiento), check-in de recuperación y
   los cuatro snapshots de Firestore. Cualquier `catch` nuevo lo hereda con solo usar `failure`.
3. **Cuatro o cinco eventos** — pendiente, y es lo único que queda de este punto. No analítica
   exhaustiva: importó de Salud (cuántos workouts), generó plan, completó sesión, hizo review
   dominical. Suficiente para saber si la app se **usa** o solo se abre. Requiere
   `FirebaseAnalytics`, que sí es un paquete aparte.

**Lo que falta antes de una beta real:** el panel de Crashlytics no muestra nada hasta que haya un
build de Release en un dispositivo. Y al enviar a App Store hay que declarar la recolección de
**datos de diagnóstico** en el App Privacy del listing (el SDK ya trae su privacy manifest, pero la
declaración del listing es responsabilidad de la app).

Lo que **no** entra: analítica de producto por pantalla, embudos, o cualquier cosa que pida
consentimiento adicional. Esto es para saber que la app funciona, no para medir gente.

> Por qué P1 y no P2: es requisito para una beta, no una mejora. Y hay que meterlo **antes** de
> tener usuarios, porque después los crashes de las primeras semanas ya se perdieron.

### Target de pruebas unitarias

**No hay target de tests.** Lo que hay son tres scripts que compilan contra los archivos reales y
corren asserts sin simulador:

| Script | Qué cubre | Asserts |
|---|---|---|
| `Scripts/check-best-split.swift` | `BestSplit.fastestWindow` (récords por tramo) | 5 |
| `Scripts/check-readiness-timing.swift` | `RaceReadiness.timing` (readiness vs. semanas) | 8 |
| `Scripts/check-adherence.swift` | `PlanAdherence`, `Campaign`, `PlanDayOutcome` | 40 |
| `Scripts/check-workout-structure.swift` | `WorkoutStructure` vs. la prosa de la guía | 16 |

Fueron la decisión correcta para no montar andamio antes de tener qué probar, y cubren la
matemática que más duele si se rompe. Pero el techo ya se ve:

- **no corren solos** — hay que acordarse de invocarlos;
- **solo llegan a `Domain/Entities`** — nada de use cases, ViewModels ni repositorios, porque en
  cuanto un tipo importa HealthKit o Firebase deja de compilar aislado;
- **no hay dobles de prueba**, así que `GeneratePlanUseCase`, `AssessRecoveryUseCase` y la
  calibración —lo más delicado del producto— no tienen una sola prueba.

Alcance propuesto:

1. **Target `RunCalendarTests`** en `project.yml` (XcodeGen lo genera; el proyecto no se versiona).
2. **Migrar los tres scripts** a Swift Testing tal cual — los asserts ya existen, es mover.
3. **Cubrir los use cases deterministas primero**: `GeneratePlanUseCase`, `SuggestPlanUseCase`,
   `AssessReadinessUseCase`, `AssessRecoveryUseCase`, `RecoveryCalibration`, `PersonalRecords`. Son
   funciones puras sobre entidades: no necesitan dobles, solo entradas.
4. **Fakes de los repositorios** (`HealthRepository` ya es un protocolo con una sola
   implementación — se le puede hacer un doble sin tocar nada) para llegar a los ViewModels.
5. **CI en GitHub Actions** que corra el target en cada PR.

> Por qué P1: cada fase que sigue mete lógica de dominio nueva, y la **Fase IA** es indefendible
> sin pruebas — un motor determinista se puede leer y verificar a mano; un plan generado por un
> modelo, no. El momento correcto de tener el target es *antes* de esa fase, no después.

### Decisión de diseño: dark-only o adaptable

Bloquea cerrar el UI Kit y rodar el look "misión" al resto de las pantallas: hasta que se decida,
cada card nueva se diseña dos veces o se diseña a medias. Es una decisión, no una tarea — pero
mientras siga abierta, todo el trabajo visual paga interés.

---

## P2 · Deuda con costo visible

### Huecos documentados de la adherencia

Todos en [adherencia.md](adherencia.md#límites-conocidos):

- **Distribución de la carga.** 30 km el domingo cuenta casi igual que 8+8+14 repartidos. Además
  es lo que impide verificar el propio aviso de sobreesfuerzo: la app aconseja *"deja un día fácil
  en medio"* y no puede comprobar si los días duros quedaron pegados. La solución es un indicador
  aparte (*adecuada / concentrada*) que **informe sin mover el porcentaje**.
- **Adherencia histórica.** Pide persistir el plan por semana (`plans/{weekStart}`): hoy es función
  del volumen de *hoy*, así que regenerarlo para una semana pasada compara contra algo que nunca
  existió.
- **Sensación térmica sin conectar.** `RaceWeather` ya la resuelve por entrenamiento desde la traza
  GPS y no entra en ningún cálculo. La plomería es trivial; lo difícil —y la razón de que siga
  pendiente— es *cuánto* ajustar por 36 °C o por 2 500 m sin inventarse un factor.
- **Altitud y desnivel no se capturan.** La traza trae `CLLocation.altitude`; `RoutePoint` no la
  guarda.
- **Entrenamiento cruzado fuera.** Deliberado (el plan es de carrera), pero para un atleta híbrido
  una semana de bici por molestia en la rodilla se ve como una semana perdida.

### Duración en minutos enteros

`HealthKitService` guarda `durationMin` redondeado, así que todo lo derivado carga ±30 s por sesión.
Los récords no dependen de eso (leen las muestras de Salud), el ritmo del detalle sí. Arreglarlo es
guardar segundos: migración de esquema en Firestore.

### Periodización lineal

`PlanUseCases` genera progresión lineal: sin mesociclos, sin semanas de descarga cada 4ª, sin taper
por tipo de carrera. Funciona para un bloque corto y se queda corto en un plan de maratón.

### Config del plan en UserDefaults

No sincroniza entre dispositivos. Mover a Firestore cuando haya más de un dispositivo por atleta.

### Umbrales sin calibrar

Recuperación (72 h), sueño (7–9 h), oscilación de peso (~1 kg), ventana de tirada larga (8 semanas),
peso volumen/frecuencia de la adherencia (2:1). Todos son constantes nombradas y aisladas a
propósito; ninguna se ha comprobado contra datos reales de nadie. Se recalibran cuando haya
usuarios, no antes.

---

## P3 · Extensiones

| Qué | Nota |
|---|---|
| **Registro de fuerza + PR de levantamiento** | La mitad **híbrida** del producto, y hoy no existe. Dominio nuevo: ejercicio × peso × reps. Es la extensión que más cambia lo que la app *es* — ver la nota de abajo |
| **Programar la sesión sola en el reloj** | `WorkoutScheduler` (WorkoutKit) deja el entreno de mañana en el Watch sin que el atleta lo mande. Hoy se manda a mano desde el detalle (`.workoutPreview`), que no pide autorización ni cuenta de pago. **Diferido a propósito hasta tener el target de pruebas**; además falta confirmar si `WorkoutScheduler` exige una *managed capability* de Apple, como Sign in with Apple |
| **Alertas de ritmo en la sesión del reloj** | `SpeedRangeAlert` haría que el reloj avise si te sales del ritmo, no solo al cerrar el tramo. Pide convertir un PR de 5K a un rango de velocidad; hoy el plan es cualitativo por principio ("nunca un dato inventado") |
| **Tab Plan propia** | Hoy el plan vive entre *Hoy* y *Objetivos*. Se promueve si se gana el espacio |
| **Varias campañas simultáneas + misiones manuales** | Requiere persistir `Campaign`, que hoy es derivada a propósito |
| **Fotos del review dominical** | Necesita Firebase Storage |
| **Widget de cuenta regresiva** | WidgetKit + App Groups → espera membresía de pago |
| **Target de Apple Watch** | watchOS |
| **Catálogo de carreras compartido** | Entre usuarios; implica backend y moderación |
| **Rename técnico a Rumbo** | Bundle id, target, scheme, Firebase. Riesgoso y sin prisa: la marca visible ya dice Rumbo |

> **Sobre el registro de fuerza.** Está en P3 por dependencias, no por importancia: es dominio nuevo
> y conviene meterlo con el target de pruebas ya montado. En cuanto exista, sube — es lo que hace
> que la app sea del atleta *híbrido* que dice ser y no solo de corredores, y hoy es la brecha más
> grande entre lo que el producto promete y lo que hace.

---

## Post-MVP

### Nutrición

Sale del plan por fases. Incluso acotada a *objetivos + adherencia por checkbox* (macros/kcal,
hidratación, ¿cumpliste hoy?) y sin food-logger, arrastra dominio nuevo, UI nueva y un modelo de
adherencia distinto al del entrenamiento — demasiado para atenderla ahora, y no es lo que hace
falta para que el MVP se sostenga.

Se retoma después del MVP. Cuando llegue, el alcance acotado sigue siendo el correcto: el momento
en que esto se vuelve un contador de calorías, deja de ser esta app.

**Consecuencia para la fase de IA:** razonará sobre objetivos + plan + adherencia + condición
(y fuerza, si ya existe), no sobre nutrición. Es suficiente para generar un plan de entrenamiento y
un reporte semanal; la parte de alimentación del [Manual](ejemplo-manual-atleta.md) queda fuera de
la primera versión del reporte.
