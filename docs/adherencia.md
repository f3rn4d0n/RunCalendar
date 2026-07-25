# Adherencia al plan

> **Qué es este documento.** Explica cómo Rumbo mide si cumpliste tu plan de la semana: qué
> cuenta, qué no, con qué números y por qué. Está aquí porque casi cada decisión es un juicio
> de entrenamiento, no una obviedad de código — y esos juicios se discuten mejor escritos.
>
> Código: `PlanAdherence` y `PlanDayOutcome` en `Domain/Entities/TrainingPlan.swift`,
> armado en `GoalsViewModel.weekAdherence` / `weekOutcomes`, mostrado en la card de misión de
> *Hoy* y en `WeekAdherenceView`. Verificación: `Scripts/check-adherence.swift`.

---

## La pregunta que responde

*"¿Cómo voy respecto al plan?"* — la tercera de las cuatro preguntas de la visión (ver
*Roadmap* en el README). El plan ya dice qué hacer hoy; la adherencia dice si lo estás haciendo.

Se responde en dos niveles:

| Nivel | Dónde | Qué dice |
|---|---|---|
| Resumen | Card de misión en *Hoy* | `2/4 sesiones · 14/30 km`, barra, una frase y el aviso de carga |
| Detalle | `WeekAdherenceView` (tocando la barra) | Día por día: qué pedía y qué corriste |

### Qué **no** mide

> La adherencia mide **cuánto del plan completaste**, no qué tan fuerte entrenaste ni cuánto vas a
> mejorar. Dos atletas con 100% pueden llevar cargas fisiológicas muy distintas.

La distinción importa porque es fácil leer el porcentaje como una nota de la semana. No lo es:

| La adherencia responde | No responde |
|---|---|
| ¿Seguiste el plan? | ¿Entrenaste bien? |
| ¿Cuánto del volumen cubriste? | ¿Con qué intensidad? |
| ¿Hiciste tus sesiones de calidad? | ¿Estabas recuperado para hacerlas? |

Una semana puede cerrar en **100% de adherencia** y al mismo tiempo traer recuperación pobre, HRV
baja y RPE elevado — en ese orden de robustez: la HRV no siempre baja ante una carga alta, mientras
que una recuperación deficiente es una señal más general. Esa otra mitad de la película vive en *Progreso* — recuperación estimada, ACWR
ponderado por RPE, tendencias — y a propósito **no** se mezcla con este porcentaje: son preguntas
distintas y juntarlas produce un número que no significa nada.

---

## Qué entra en la cuenta

Solo **sesiones de correr completadas** de la semana en curso (`type == .running`,
`completed == true`, desde `plan.weekStart`).

Caminata y senderismo **no** cuentan. Es el mismo criterio que ya usa el generador del plan: un
plan de carrera se construye sobre volumen de carrera, y contar caminatas inflaba el volumen y
disparaba avisos falsos de *"no cabe en 3 días"*.

## Los cuatro números

```swift
plannedSessions / completedSessions      // frecuencia
plannedKm / completedKm                  // volumen
plannedHardSessions / completedHardSessions   // calidad (tempo + series)
completedMinutes                         // informativo: el plan da km, no minutos
```

### Se comparan totales de la semana, no día contra día

Si el plan pedía series el martes y corriste el miércoles, **cuenta**. Lo que determina gran parte
de la adaptación fisiológica es la carga acumulada de la semana, no el casillero del calendario.
Mover una sesión es normal y no debería castigarse.

El detalle día por día sí existe (`PlanDayOutcome`), pero es para *explicar*, no para calificar:
el porcentaje sale de los totales.

### El volumen pesa el doble que la frecuencia

```swift
var fraction: Double { (kmFraction * 2 + sessionFraction) / 3 }
```

En corredores recreativos el **volumen semanal** suele asociarse más con las adaptaciones
aeróbicas que el número exacto de sesiones: dos sesiones largas que cubren los 30 km entrenan más
que cuatro cortas que se quedan en 15 km. La frecuencia entra con la mitad del peso porque también importa
(correr 30 km de un jalón no equivale a repartirlos), pero no manda.

El 2:1 es una aproximación conceptual, no una constante de la literatura. Vive en un solo lugar
(`fraction`) precisamente para poder recalibrarlo: cuando haya corredores usando la app, habrá que
comprobar si esa ponderación coincide con lo que ellos *sienten* como semana cumplida, y moverlo
sin tocar nada más.

### Correr de más no pasa de 100%

```swift
static func fraction(_ done: Double, of planned: Double) -> Double {
    planned > 0 ? min(done / planned, 1) : (done > 0 ? 1 : 0)
}
```

El plan es un **piso, no una cuota que se sobregira**. Premiar el exceso con un 140% invitaría
justo a lo que el plan intenta evitar. El exceso sí se nombra, pero como advertencia (abajo).

### Cómo se decide que una sesión fue "de calidad"

**Unión de dos señales**, no una prioridad: cuenta como dura si *el plan pedía calidad ese día*
**o** si su *RPE ≥ 7*. El RPE se importa del Apple Watch (`workoutEffortScore`) y `RPEPromptCard`
lo pide cuando falta.

Ninguna de las dos alcanza sola:

- **Solo RPE** se queda corto. Unas series bien controladas pueden salir en RPE 6 y siguen siendo
  trabajo de calidad. El tipo planeado las reconoce.
- **Solo el plan** se queda ciego a lo que no planeó. Si intentaste series el martes, no salieron,
  y las repites el miércoles, el calendario diría *"el miércoles tocaba fácil, entonces fue
  fácil"* — y el aviso de carga no vería nada. El RPE sí, porque no depende del día.

**Suma de más a propósito.** Para el aviso de carga interesa *toda* la intensidad de la semana,
venga del plan o no. Un trail duro con RPE 9 va a contar como sesión dura: como **carga** lo es,
aunque como **trabajo** no sustituya al tempo. Ese es el límite conocido de usar RPE — mide
esfuerzo, no tipo de entrenamiento — y se acepta porque el lado en que se equivoca es el prudente.

---

## El aviso de carga extra

`PlanAdherence.extraLoadWarning` — la parte que no es contabilidad sino consejo. Tres estados,
en orden de prioridad:

| Situación | Aviso |
|---|---|
| `completedHard > plannedHard` | *"Llevas 3 sesiones de calidad y el plan pedía 2. El exceso de intensidad no acelera nada: baja el resto de la semana a fácil."* |
| `missedHard > 0` | *"Se te fue una sesión de calidad. Si la reprogramas, deja al menos un día fácil o de descanso entre sesiones intensas — lo que hace daño es acumularlas para compensar, no moverlas."* |
| Cuota cubierta | *"Ya cubriste tus 2 sesiones de calidad de la semana. Lo que falte, en fácil."* |
| Al día, a media semana | nada — no se regaña sin motivo |

**Por qué existe.** La reacción natural a perder la sesión de series es hacerla al día siguiente.
El problema no es *mover* la sesión —cambiar el tempo del martes al miércoles suele estar
perfectamente bien— sino **encadenar intensidad para compensar**. El plan alterna duro/fácil
precisamente para que el cuerpo asimile; dos sesiones duras seguidas quitan el día de asimilación
y ahí es donde salen las lesiones.

Por eso el aviso no prohíbe reprogramar: pide **dejar un día fácil o de descanso en medio**. Es la
regla que de verdad protege, y la versión anterior del texto ("no la repongas") era una prohibición
absoluta que no se sostiene: hay reprogramaciones perfectamente sanas.

Lo que el aviso **no** puede ver todavía: si los días duros quedaron consecutivos. Cuenta cuántas
sesiones de calidad hubo, no cómo se acomodaron (ver *No mira cómo se distribuyó la carga*). El
consejo es correcto; la detección del caso concreto es lo que falta.

**Es un aviso, no un candado.** La app no impide registrar ni entrenar lo que quieras — dice el
costo y te deja decidir. Endurecerlo (bloquear, esconder la sesión) sería tratar al atleta como
si no supiera lo que hace.

---

## El día por día

`PlanDayOutcome` compara, para cada día de la semana, lo pedido con lo hecho. Seis estados:

| Estado | Cuándo | Ejemplo de la frase |
|---|---|---|
| `done` | corriste al menos el mínimo tolerado | *"pedía Tempo de 8 km · hiciste 8.2 km en 42 min"* |
| `partial` | corriste, pero menos | *"pedía Tempo de 8 km · hiciste 5.2 km en 30 min, faltaron 2.8 km"* |
| `missed` | el día pasó sin sesión | *"pedía Series de 6 km · sin sesión ese día"* |
| `extra` | era descanso y corriste | *"era descanso · corriste 6 km"* |
| `rest` | descanso respetado | *"descanso"* |
| `upcoming` | el día aún no llega | *"toca Tirada larga de 14 km"* |

Tres detalles que importan:

- **Tolerancia híbrida** `max(500 m, 5%)` (`minimumKm(for:)`), no un porcentaje fijo. Un 10% de
  4 km son 400 m (irrelevantes) y un 10% de 20 km son 2 km (media hora de trote): el mismo
  porcentaje significa cosas muy distintas según la distancia. El **piso absoluto** cubre lo corto
  y la **fracción** cubre lo largo, y manda el mayor. En la práctica: 3.6 de 4 km cuenta, 3.4 no;
  19.2 de 20 cuenta, 18 no.
- **Los días que no llegaron no se juzgan.** Salen como `upcoming`, no como fallados. Un plan que
  te dice el lunes que ya fallaste el sábado no sirve de nada.
- **Se recorren en el orden real de tu semana**, no 1…7. El número de `weekday` es 1 = domingo,
  así que con semana que empieza en lunes el domingo tiene el número más bajo pero es el último
  día. Lo resuelve `PlannedDay.position(of:)`.

---

## Límites conocidos

**Solo la semana en curso.** El plan **no se persiste** — es una función pura de tus metas + tu
volumen actual + tu config, y se recalcula reactivo. Regenerarlo para una semana pasada usaría tu
volumen de *hoy* y daría un plan distinto al que viste entonces, así que la adherencia histórica
sería una comparación contra algo que nunca existió. Para tenerla hay que **guardar un snapshot
del plan por semana** (`plans/{weekStart}`), que es el trabajo que falta.

**No se sabe cuál sesión fue el tempo.** `TrainingSession` no guarda `PlannedWorkoutKind`. Se
sustituye con el RPE, que para contar sesiones duras alcanza. Persistir el tipo daría adherencia
por tipo exacta (*"te faltó el tempo, no las series"*) — pero como todo lo que se puede derivar
para la semana en curso, y la semana en curso es la única que se mide, hoy no compra nada.

**Los minutos vienen redondeados.** `durationMin` guarda minutos enteros (±30 s por sesión). Da
igual para `completedMinutes`, que es informativo; donde el segundo importa —los récords— el
tiempo se lee de las muestras de Salud.

**El intento no se distingue del resultado.** Si sales a hacer series, te sientes mal y terminas
trotando, los datos ven un rodaje fácil. Tienen razón: la carga fue de rodaje fácil. Pero la app
no puede saber que *intentaste* otra cosa, y no hay campo donde decírselo.

**No mira cómo se distribuyó la carga.** Un plan de 8 + 8 + 14 km cumplido como *30 km el domingo*
da casi el mismo porcentaje, y fisiológicamente no es lo mismo. El día por día lo deja ver, pero
nada lo resume ni lo advierte. La forma correcta de resolverlo sería un indicador aparte
(*distribución: adecuada / concentrada*) que **informe sin mover el porcentaje** — mezclarlo con la
adherencia volvería a producir un número que responde dos preguntas a la vez.

**No mira la intensidad real de lo que corriste.** 30 km fáciles y 30 km a ritmo de 5K dan 100%
igual, con cargas muy distintas. Esto **sí existe en la app**, pero en otro lado: `sessionLoad`
(RPE × minutos) y el **ACWR ponderado por RPE** en *Progreso*. Está separado a propósito (ver
*Qué no mide*); lo que falta es que la vista de la semana **enlace** a esa lectura en vez de
dejar al atleta creyendo que el 100% ya lo dice todo.

**El entrenamiento cruzado no aporta nada.** Bici, natación, remo y SkiErg no suben la adherencia
—igual que la caminata— porque el plan es de carrera y su volumen se mide en kilómetros corridos.
**Es deliberado**: la adherencia responde si cumpliste el *plan de carrera*, no estima la carga
total de tu semana de entrenamiento. Pero tiene un costo real: una semana de cross-training por
molestia en la rodilla se ve como una semana perdida. Para un atleta híbrido, que es a donde va el
producto, esto va a tener que cambiar.

**No considera las condiciones ambientales.** 20 km planos a 8 °C y 20 km a 36 °C con humedad alta
y en altura cuentan exactamente igual, con costos fisiológicos que no se parecen. Es deliberado por
la misma razón que la intensidad: la adherencia mide el **cumplimiento del plan**, no el costo de
ejecutarlo.

Vale la pena separar qué falta de qué no:

| Factor | ¿Está el dato? |
|---|---|
| Temperatura, **sensación térmica**, humedad, viento | **Sí** — `RaceWeather`, ya se resuelve por entrenamiento desde la traza GPS (`TrainingViewModel.weather(for:)`) y se muestra en el detalle. Simplemente no entra en ningún cálculo |
| Altitud y desnivel acumulado | **No** — la traza GPS trae la altitud de cada punto (`CLLocation.altitude`), pero `RoutePoint` no la guarda |
| Terreno (asfalto / trail / caminadora) | Parcial — `RaceDiscipline.trail` existe para carreras y ya se excluye de los récords, pero un entrenamiento no distingue superficie |

O sea que la mitad del problema es de *plomería*, no de datos: la sensación térmica ya está a mano.
Lo que no está resuelto es la parte difícil — cuánto ajustar por 30 °C o por 2 500 m es un modelo
en sí mismo, y ponerle un factor inventado sería peor que no tenerlo.

**No hay modo lesión, enfermedad ni descarga.** Con gripe o lesión, no entrenar es la decisión
médicamente correcta y la adherencia la castiga con un 0%. Falta poder marcar la semana
(*lesionado / enfermo / descarga*) para pausar la medición en vez de acumular culpa por haber
hecho lo correcto. Es la limitación que más urge de esta lista.

**Todas las sesiones pesan igual por kilómetro.** Una tirada larga y un rodaje corto solo se
diferencian por su distancia; no hay ponderación por tipo. Una evolución natural sería pesar
tirada larga ≈ 2, tempo y series ≈ 1.5, fácil = 1 — deliberadamente pendiente hasta que haya
razón para creer que los números importan más que la simplicidad de contar kilómetros.

---

## Sobre dejar la API "preparada"

Una tentación recurrente es añadir ya los campos de las extensiones futuras
(`loadDistributionScore`, `trainingLoadScore`) inicializados en `nil`, para no romper
compatibilidad después. **No se hace.** Un campo que siempre vale `nil` es un campo que hay que
mantener, serializar y explicar, y que además miente en el tipo: promete un dato que nadie calcula.
`PlanAdherence` es un struct derivado que no se persiste — agregarle una propiedad el día que
exista algo que poner en ella cuesta exactamente lo mismo que agregarla hoy, y ese día se sabrá
qué tipo debe tener.

Lo que sí queda preparado, y es lo que de verdad importa: la matemática vive en el entity como
funciones puras (`fraction`, `extraLoadWarning`, `status`, `minimumKm`), verificables sin
simulador. Cualquiera de estas extensiones entra ahí sin tocar la UI.

---

## Verificación

```bash
swiftc RunCalendar/Domain/Entities/TrainingPlan.swift RunCalendar/Domain/Entities/Goal.swift \
  RunCalendar/Domain/Entities/Campaign.swift RunCalendar/Domain/Entities/Race.swift \
  Scripts/check-adherence.swift -module-name check -o /tmp/check-adherence && /tmp/check-adherence
```

40 asserts sobre la matemática pura, sin simulador ni target de tests. Los que valen la pena
mirar antes de cambiar algo:

- que 2 sesiones largas cubriendo el km **superen** a 4 cortas a medias (el peso del volumen);
- que correr de más **no** pase de 100%;
- que un plan vacío no divida entre cero;
- que a media semana sin días perdidos **no** se advierta nada;
- que la posición del día salga bien con semana en lunes **y** en domingo;
- los seis estados de `PlanDayOutcome` y la tolerancia híbrida por los dos lados (3.6 de 4 sí,
  3.4 no; 19.2 de 20 sí, 18 no);
- que el aviso de sesión perdida **no** sea una prohibición: el assert falla si el texto vuelve a
  decir "no la repongas".

Sin `-O`: en release los `assert` se compilan fuera y el check no verificaría nada.
