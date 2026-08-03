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
3. ✅ **Cinco eventos de uso.** Hecho, todos en `RunCalendar/Core/Utils/Usage.swift`:
   `health_imported` (con el conteo), `plan_configured` (días/semana + si vino de la sugerencia),
   `session_completed`, `weekly_review_saved` y `workout_sent_to_watch`. Responden *¿la app se usa
   o solo se abre?*, que es la pregunta que solo se puede contestar **antes** de la beta.

   Decisiones que no son obvias al leerlo:

   - **Todo sale de un archivo.** La revisión de privacidad es leer una pantalla, no auditar el
     proyecto. La regla es que aquí no viaja ningún dato del atleta: solo conteos y `case`s
     nuestros. Nada de nombres, notas, kilometrajes, pesos, fechas ni ids.
   - **No se manda el `rawValue` de los enums.** Esos son los textos de la UI ("Tirada larga"), y
     cambiarlos por redacción rompería la serie histórica del panel sin que nadie lo relacione. Va
     una clave estable en inglés, de un `switch` exhaustivo — así el compilador obliga a decidir
     cuando alguien agregue un `case`.
   - **`health_imported` se manda también con cero.** "El import corre y siempre trae cero" y "el
     import nunca corre" se ven igual desde fuera y no son el mismo problema.
   - **`plan_configured` sale al cerrar la hoja, no en el `didSet`.** El stepper dispara en cada
     toque: subir de 3 a 7 días son cuatro cambios y una sola decisión. Y solo si algo cambió —
     abrir para mirar el plan y cerrar no es haberlo configurado.
   - **Importar de Salud no cuenta como sesión completada.** `session_completed` sale del alta a
     mano y del check; lo importado ya lo cuenta `health_imported`.

**Lo que falta antes de una beta real:** el panel de Crashlytics no muestra nada hasta que haya un
build de Release en un dispositivo. Y al enviar a App Store hay que declarar en el App Privacy del
listing la recolección de **datos de diagnóstico** (Crashlytics) y ahora también de **datos de uso**
más el **identificador de instancia** que Analytics genera (el SDK trae su privacy manifest, pero la
declaración del listing es responsabilidad de la app).

> **No agregues `FirebaseAnalyticsIdentitySupport`.** Es el producto SPM que trae el IDFA: obliga a
> pedir permiso de seguimiento y mueve la declaración de privacidad al terreno de la publicidad.
> Está anotado también en `project.yml`, que es donde alguien lo agregaría sin querer.

Lo que **no** entra: analítica de producto por pantalla, embudos, o cualquier cosa que pida
consentimiento adicional. Esto es para saber que la app funciona, no para medir gente.

> Por qué P1 y no P2: es requisito para una beta, no una mejora. Y hay que meterlo **antes** de
> tener usuarios, porque después los crashes de las primeras semanas ya se perdieron.

### Pruebas unitarias

**Target `RunCalendarTests`** (Swift Testing), hospedado en la app para que `@testable import
RunCalendar` alcance los casos de uso y no solo lo que compila aislado. ⌘U, o:

```bash
xcodebuild test -scheme RunCalendar -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

| Suite | Qué cubre | Pruebas |
|---|---|---|
| `BestSplitTests` | `BestSplit.fastestWindow` (récords por tramo) | 4 |
| `RaceReadinessTests` | `RaceReadiness.timing` (readiness vs. semanas) | 6 |
| `PlanAdherenceTests` | adherencia, campañas, día por día, `WeekStatus` | 19 |
| `WorkoutStructureTests` | `WorkoutStructure` vs. la prosa de la guía | 10 |
| `GeneratePlanTests` | **el motor del plan**, por invariantes | 20 |
| `RecoveryTests` | recuperación y calibración, por propiedades | 16 |
| `RecompositionTests` | recomposición (peso quieto + cintura bajando) | 5 |
| `RacesInPlanTests` | carreras inscritas + víspera protegida | 18 |
| `GoalsViewModelTests` | **el cableado**: qué alimenta el plan, siembra de días, semana empezada, pausas, adherencia | 33 |
| `RacesViewModelTests` | gasto del año, motivos de clima ausente, calendario | 12 |

Los cuatro scripts de `Scripts/` se migraron y se borraron: ya no hay que acordarse de invocarlos.
También se borraron los dos `selfCheck()` de andamio — uno corría en **cada arranque** de la app en
DEBUG y el otro vivía en un preview de SwiftUI, así que en la práctica **nunca corría** (al migrarlo
falló a la primera, ver *El plan descarta volumen sin avisar* abajo).

Al motor se le prueban **invariantes** (80/20, techo de progresión, tirada larga como día más
largo, taper, días duros no encadenados, determinismo), **no números exactos**. Es deliberado: las
constantes están sin calibrar (ver abajo) y fijarlas en una prueba cementaría valores que nadie ha
comprobado contra datos reales — la prueba pasaría a defender el número en vez de la regla.

**Dobles de repositorio** (`RunCalendarTests/Doubles.swift`) ✅: uno por protocolo de la capa
Domain, más un `TestApp` que arma los tres ViewModels cableados igual que `AppContainer`. No hizo
falta tocar producción — los ViewModels ya reciben casos de uso y los casos de uso protocolos.

Tres detalles que cuestan una tarde si no se saben:

- El stream de un doble tiene que **cerrar** tras emitir. Contra Firestore queda abierto escuchando
  cambios, así que un doble fiel al original colgaría `await viewModel.start()` para siempre.
- `planConfig`, `weekStatus` y las claves del calendario viven en `UserDefaults`, que en pruebas es
  **compartido**. Sin `clearPersistedDefaults()` en el montaje, la lesión que deja una prueba hace
  fallar a la siguiente por un motivo que no tiene que ver con ella. Por eso esas suites van
  `.serialized`.
- **Cuidado con los `didSet` de propiedades del ViewModel.** En una clase, asignar en el `init` a
  una propiedad que ya tiene valor por defecto **sí dispara** el observador. Eso persistía la
  `PlanConfig` antes de que nadie la eligiera, y la siembra desde el historial creía que ya estaba
  configurada. Se arregla leyéndola en el valor inicial de la propiedad (ahí los observadores no
  corren) en vez de asignarla en el `init`. Hay una prueba que lo fija.
- **Nada que dependa del día en que corran las pruebas** — ni las aserciones **ni los datos de
  entrada**. Los ViewModels leen `Date()` directo, así que una prueba escrita un sábado puede pasar
  en local y fallar el domingo en CI. Ha pasado dos veces:

  1. *La semana día por día* daba por hecho que todo día futuro es `.upcoming`, cuando un día
     futuro **sin sesión planeada** es `.rest`.
  2. Un historial de prueba se construía contando `daysAgo` hacia atrás, pero `SuggestPlanUseCase`
     agrupa por `weekOfYear`: cerca del borde de la semana el bloque se parte en dos y el promedio
     de días/semana sale más bajo.

  Salidas: derivar lo esperado de los propios datos del resultado, fijar el día con
  `preferredWeekdays`, y construir los históricos **alineados a semanas de calendario** (desde
  `dateInterval(of: .weekOfYear)`) en vez de a bloques de días. Y cuando el montaje sea el que
  puede fallar, comprobarlo aparte: una aserción sobre el dato de entrada distingue "el fixture
  está mal" de "el código está mal".

**Lo que falta:**

1. `HealthViewModel` y `TrainingViewModel` siguen sin pruebas propias (los dobles ya están; falta
   escribirlas). El import de Salud —deduplicar contra lo que ya existe— es lo que más lo pide.
2. ~~**CI en GitHub Actions**~~ ✅ hecho: `.github/workflows/pruebas.yml` corre el target en cada
   PR — **solo ahí**, no en cada push a `main`. Antes eran las dos cosas y cada cambio se probaba
   dos veces (una en la rama, otra al mergear). Lo que la corrida de `main` protegía era que `main`
   avanzara entre que se probó el PR y se mergeó, y eso lo cubre ahora **"Require branches to be up
   to date before merging"** en la protección de `main`: no deja mergear hasta que la rama contenga
   la punta de `main`, así que lo probado y lo mergeado son idénticos. **Si algún día se quita esa
   protección, hay que devolver el disparador `push: branches: [main]`** — sin una ni la otra, nada
   prueba lo que queda en `main`. Queda un `workflow_dispatch` para correrlas a mano sobre `main`.
   El repo es público, así que los runners de macOS no cuestan minutos. **No metas `paths-ignore`**
   para saltarte cambios de solo documentación: con un check requerido, un PR que solo toca `.md`
   se queda esperando para siempre un check que nunca va a correr.
   Los archivos gitignored (`Secrets.xcconfig`, `GoogleService-Info.plist`) se crean como
   placeholders en el runner; el `API_KEY` falso **debe** tener el formato que Firebase valida
   (39 caracteres, empieza con `A`) o la app anfitriona lanza una excepción al arrancar y el
   runner de pruebas muere antes de conectarse.
3. ~~**Recuperación y calibración**~~ ✅ hecho: 16 pruebas de **propiedad** (monotonía por HRV /
   sueño / carga / FC, acotamiento, ausencia de datos, clamp y dirección del ajuste). Atraparon un
   defecto real, ver *El techo de la recuperación* abajo.

> Por qué P1: cada fase que sigue mete lógica de dominio nueva, y la **Fase IA** es indefendible
> sin pruebas — un motor determinista se puede leer y verificar a mano; un plan generado por un
> modelo, no.

### ~~Decisión de diseño: dark-only o adaptable~~ ✅ resuelto: **dark-only**

La app fija `UIUserInterfaceStyle: Dark` en `project.yml` — en el Info.plist y no con
`.preferredColorScheme(.dark)`, para que también cubra lo que presenta UIKit (alertas, teclado,
hojas de Salud/Calendario). `Neon` perdió las variantes `light` y quedó en un solo valor por color.

**Por qué dark-only:** la identidad del Kit es dark-first, todo el diseño existente se hizo así, y
sostener una paleta clara en paralelo obligaba a diseñar cada card nueva dos veces por un modo que
nadie pidió. Consecuencia para quien siga: **no agregues variantes claras ni ramas `colorScheme`**;
si algún día se quiere modo claro, se restituye el helper `adaptive(light:dark:)` en `Neon.swift`.

---

## P2 · Deuda con costo visible

### El modelo de recuperación

~~**El techo de 72 h no topaba nada.**~~ ✅ resuelto: el tope se aplicaba a las horas de carga y
los factores (HRV × FC × sueño × calibración, hasta ~4×) multiplicaban **después**, así que el
estimado llegaba a **194 h — 8 días — y a 290 h con la calibración al máximo**, y el anillo de
*Hoy* lo mostraba tal cual. Ahora se topa el resultado final (`AssessRecoveryUseCase
.maxRecoveryHours`) y hay dos pruebas que lo fijan.

Lo que **sigue pendiente** del modelo, por orden de valor:

1. **El HRV se usa crudo, de un solo día.** La FC en reposo se promedia a 7 días *"porque el dato
   de un día es muy ruidoso"* (README) y el HRV es **más** ruidoso (±10–20% noche a noche). Aplicar
   el mismo criterio —media de 3–7 días— es la mejora que más estabiliza el número, y usa una regla
   que el proyecto ya tomó.
2. **Los escalones dan saltos absurdos.** Un ratio de HRV de 0.899 da factor 1.3 y 0.901 da 1.0:
   **0.2% de cambio mueve el estimado 30%**. Interpolar linealmente entre los mismos umbrales
   conserva el modelo y quita el salto. Igual en los tramos de sueño.
3. **Sin fecha del último entreno se declara "recuperado".** `elapsed = hoursSinceLastWorkout ??
   needed` convierte la falta de dato en la afirmación más optimista posible. Debería ser un estado
   desconocido, no un verde.
4. **`isHighLoad` no es una condición adversa.** Se define como *por encima de la mediana*, o sea
   **la mitad de los días por construcción**: el segmento siempre se activa y no distingue nada.
   Debería ser un percentil alto o un umbral absoluto.
5. **Los tres offsets se suman como si fueran independientes.** HRV baja, poco sueño y carga alta
   están correlacionados (la mala noche *después* de la sesión dura *baja* el HRV): es un evento
   contado tres veces. El clamp evita que explote, pero eso significa que justo en los días que más
   importan la corrección **satura** y deja de informar.
6. **La calibración no mide si mejora.** Existe la gráfica "¿acierta el modelo?" pero nada compara
   el error medio antes y después de calibrar — que es lo único que responde si la feature sirve.

> **1–3 se pueden hacer ya** (son del modelo, no de los datos). **4–6 esperan usuarios reales**:
> recalibrar segmentos sin registros de nadie es justo lo que dice *Umbrales sin calibrar*.

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

### Una carrera sin distancia se ve como "descanso" en la semana

`PlanDayOutcome.status` decide con `plannedKm`. Una carrera Trail/Otra **sin distancia capturada**
entra al plan con `targetKm == nil`, así que ese día aparece como *Descanso* (o *Extra* si la
corriste) en la vista día por día, en vez de como la carrera que es.

Es el borde de un borde —hace falta una carrera de distancia variable *y* no haber capturado los
km, y el propio plan ya pide capturarlos— así que no se arregló: la solución honesta es que
`PlanDayOutcome` distinga "día fijo sin meta de km" de "descanso", y eso es un caso más en un
enum que hoy nadie está pidiendo.

### El plan descarta volumen sin avisar

Con las sesiones de calidad topadas, parte del volumen no cabe: `allocate` devuelve el sobrante
(`unfit`) y el plan solo avisa **arriba de `unfitThresholdKm` (5 km)**. Debajo de ese umbral los
kilómetros simplemente desaparecen.

Caso real, encontrado al migrar los self-checks a pruebas: **40 km en 3 días** genera un plan de
37 km y `note == nil`. El atleta pidió 40, recibe 37, y nada se lo dice — mientras el README
promete *"si aún no cabe, avisa subir días en vez de inflar"*.

No se arregló aquí porque el arreglo es **elegir un número nuevo** (¿1 km? ¿un % del volumen?) y
eso es calibrar a ojo, justo lo que dice *Umbrales sin calibrar*. Lo defendible sin datos es que
el aviso dependa de la **fracción** del volumen, no de un absoluto: 3 km sobre 40 es 7.5% y merece
mención; 3 km sobre 120 no.

### Los dos escalones del taper están sin calibrar

*(El defecto de fondo —el taper recortaba también la intensidad— ya está arreglado: `taperFactor`
en `GeneratePlanUseCase`. Lo que queda es la calibración.)*

El afinamiento aplica dos factores fijos al volumen fácil: `0.75` la penúltima semana y `0.50` la
de la carrera; la calidad se recorta la mitad de eso (`(1 + taper) / 2`), que es el "menos
repeticiones, mismo ritmo". El total de la semana de carrera cae ~42%, dentro del rango de la
literatura.

Lo que no está calibrado es que **son los mismos dos escalones para toda meta**. Un 5K afina
distinto que un maratón: la literatura describe el recorte como exponencial y proporcional a la
carga previa, y aquí es una escalera de dos peldaños igual para todos. Del mismo grupo que
*Umbrales sin calibrar*: se arregla cuando haya atletas reportando llegar pesados o pasados de
rosca, no antes.

Referencia de lo que se implementó (meta-análisis de Bosquet et al. 2007, confirmado por revisiones
más recientes):

| Variable | Qué hacer |
|---|---|
| **Volumen** | bajar **41–60%**, de forma exponencial |
| **Intensidad** | **no tocar** |
| **Frecuencia** | **no tocar** |
| **Duración** | ~**2 semanas** (≤ 21 días) |

> **Contexto de por qué importa:** el efecto de un taper bien hecho es del orden del 2–3% en
> rendimiento. Sobre un medio maratón de 2 h son 2–4 minutos — más de lo que mueve casi cualquier
> otra cosa que la app pueda sugerir.

Fuentes: [Bosquet et al., *Effects of tapering on performance: a meta-analysis*](https://www.semanticscholar.org/paper/Effects-of-tapering-on-performance:-a-Bosquet-Montpetit/a41517ab5fa06b92568b861e2b1aa32b3003d214) ·
[*Effects of tapering on performance in endurance athletes* (PLOS One, 2023)](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0282838)

### El plan se reescribe solo mientras lo sigues

`currentWeeklyKm` es una suma **móvil de 7 días**, así que cada carrera que registras sube la base
y el plan recalcula objetivos más altos. **El plan que viste el lunes no es el que ves el jueves**,
y la adherencia te mide contra el del jueves, no contra el que aceptaste. "Seguir el plan" es
imposible por construcción.

Es la misma raíz que ya bloquea la adherencia histórica: el plan **no se persiste**, es una función
pura de tu volumen de hoy. Regenerarlo para una semana pasada da un plan distinto al que viste.

El arreglo es **congelar la semana**: al generarla por primera vez, guardar una foto (días, km,
`plansFrom`) y usar esa hasta que empiece la siguiente.

> Mientras tanto, la vista previa presenta los días pasados con **lo que de verdad corriste** en vez
> de con el plan que había. Cubre el 80% de la necesidad (revisar la semana un domingo) sin
> persistir nada, y de hecho para revisar sirve más: lo que hiciste es un hecho, y el plan que te
> prometieron el lunes ya no es accionable. Lo que **no** cubre es seguir un plan estable, que es
> el motivo de fondo para congelarlo. Con eso caen tres cosas de golpe —
adherencia histórica, un plan estable que seguir, y poder comparar lo planeado con lo hecho semanas
después.

No se hizo junto con lo de la semana ya empezada porque es de otra naturaleza: aquello son reglas
de colocación dentro de un plan derivado, y esto cambia el plan de derivado a **persistido**, con
su documento en Firestore, su migración y su decisión de cuándo invalidarlo (¿cambiar los días
regenera la semana en curso, o solo la siguiente?).

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
