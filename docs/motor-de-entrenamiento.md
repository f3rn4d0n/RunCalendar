# El motor de entrenamiento: lo que hay, lo ideal y a dónde vamos

> **Qué es este documento.** Una foto honesta del motor que genera tu semana (`GeneratePlanUseCase`)
> frente a lo que sostiene la evidencia, y el orden en que pensamos cerrar la distancia. Sirve para
> decidir qué construir después sin repetir la discusión cada vez.
>
> El backlog operativo sigue en [pendientes.md](pendientes.md); esto es el *porqué* de la parte de
> entrenamiento.

## Cómo leer la columna de evidencia

No todo lo que suena a ciencia del deporte pesa igual. Se distingue:

| | Significa |
|---|---|
| **Sólido** | Ensayos o meta-análisis que lo sostienen directamente |
| **Principio** | El mecanismo está bien establecido, pero el número concreto es convención |
| **Tradición** | Práctica extendida entre entrenadores, evidencia floja o ausente |
| **Mito** | Circula mucho y la evidencia lo contradice o no lo apoya |

Esta distinción es la que evita que la app dé consejo con más seguridad de la que tiene.

---

## La tabla

### Motor de volumen

| | Hoy | Evidencia | Propuesta |
|---|---|---|---|
| **Progresión semanal** | ✅ Acompasada a la meta: se reparte el crecimiento que hace falta entre las semanas que quedan, con el 8% de tope | La "regla del 10%" es **tradición**: un ECA con 532 novatos no encontró diferencia en lesiones entre un programa graduado y uno estándar. Lo que sí aparece es que saltos **>30%** aumentan lesiones | Techo por **ACWR** en vez de un porcentaje fijo, y escalones que se achican al acercarse a tu techo |
| **De dónde sale la base** | ✅ Máximo de las últimas 4 semanas de calendario | — | Base estable (media de 28 días o máximo de las últimas 3 semanas) |
| **Semanas de descarga** | ✅ Cada 4ª contando hacia atrás desde la meta: volumen −40%, intensidad intacta | **Principio**: sin recuperación planificada la sobrecarga deja de adaptar. La cadencia exacta (cada 3ª o 4ª) es convención | Cada 4ª semana: volumen −40%, intensidad intacta — la misma regla del taper |
| **Techo de carga** | ✅ ACWR: el volumen no pasa de 1.3× tu carga crónica (media de 4 semanas) | **ACWR** (agudo 7 d / crónico 28 d) es mejor gobernador que un % fijo, con la crítica metodológica de Impellizzeri et al. encima | Cablearlo al plan |
| **Taper** | ✅ 2 semanas, volumen −40/50%, intensidad intacta | **Sólido** (Bosquet et al., meta-análisis de ~50 estudios) | Sin cambios |

> **El bloqueador que había.** La base salía de tu propio output de la semana pasada, así que una
> descarga al 60% hacía que el motor creyera que bajaste de forma y arrancara desde ahí — el motor
> peleaba contra su propia periodización. Resuelto tomando el **máximo** de las últimas 4 semanas:
> sube cuando de verdad subes y no se hunde con una semana suave. Si dejas de correr de verdad, las
> cuatro caen y la base baja con ellas, que es lo correcto.

### Motor de calidad

| | Hoy | Evidencia | Propuesta |
|---|---|---|---|
| **Distribución de intensidad** | Pesos de volumen; la prueba solo fija que la calidad no se lleve más del 50% | El **80/20** está **sólido** (Seiler y otros) — pero se define por *tiempo* o *sesiones*, no por km | Medirlo como toca antes de presumir de 80/20 |
| **Tipos de sesión** | ✅ Rota entre cortas (VO₂max), largas (umbral), cuestas y fartlek; cerca de la meta pasa a ritmo de carrera. Las cuestas salen de la rotación si el atleta no tiene dónde hacerlas | **Sólido**: repeticiones cortas y largas no dan el mismo estímulo. Solo 5×800 deja fuera velocidad y umbral | Variar el tipo de calidad **a lo largo del bloque** |
| **Cuestas, rectas, progresivos, ritmo de carrera** | ✅ Cuestas y ritmo de carrera. Faltan rectas y progresivos | Cuestas y rectas: **principio** (fuerza específica, economía). Ritmo de carrera: **sólido** para especificidad | Al menos ritmo de carrera cerca de la meta |
| **Fartlek vs. series en pista** | ✅ Entra en la rotación, **etiquetado como lo que es** — la tarjeta dice «el mismo estímulo, en otro envoltorio» | A intensidad y duración iguales el estímulo es **equivalente**. Cambiar el envoltorio no adapta más — eso es el **mito** de la "confusión muscular" | Sí, pero **por adherencia**: el disfrute predice la constancia y la constancia predice el resultado. Y se dice así en la app, sin fingir fisiología |

### Estructura temporal

| | Hoy | Evidencia | Propuesta |
|---|---|---|---|
| **Mesociclos / bloques** | No existen. Cada semana se genera desde cero | **Principio** para la alternancia carga/descarga | Bloque persistido: inicio, carrera objetivo, volúmenes por semana |
| **Fases base → build → pico** | No existen | **Tradición.** La superioridad de la periodización por fases en corredores recreativos está peor sostenida de lo que su popularidad sugiere | **Última de la lista.** Mete varias constantes sin calibrar |
| **El plan persiste** | No. Es función pura de tu volumen de hoy | — | Sale gratis con el bloque |

### Individualización

| | Hoy | Evidencia | Propuesta |
|---|---|---|---|
| **Recuperación (HRV, sueño, FC)** | Se calcula y se muestra en *Condición* | — | — |
| **¿Alimenta el plan?** | ✅ **Parcialmente**: el plan calcula su propio ACWR en km y lo usa de techo. `RecoveryCalibration` (RPE) sigue solo en Progreso | — | Cablear también la calibración |
| **Calibración por RPE** | Ajusta la estimación de recuperación con tu feedback | — | Mismo camino, más adelante |

---

## Lo que ya está bien y no hay que tocar

- **El taper.** Es lo mejor sostenido del motor y ya está implementado como dice la evidencia.
- **Los topes por sesión.** Una serie es por repeticiones, no un balde de km.
- **Carreras inscritas y víspera protegida.** Reglas de colocación, sin números inventados.
- **Avisar en vez de inflar.** Cuando el volumen no cabe, el motor lo dice en lugar de meter sesiones enormes. Es la postura correcta y conviene mantenerla en todo lo que sigue.

## Orden propuesto

1. ~~**Base estable**~~ ✅
2. ~~**Descargas cada 4ª semana**~~ ✅
3. ~~**Techo por ACWR**~~ ✅
4. ~~**Escalones decrecientes**~~ ✅ — salen solos del ritmo acompasado a la meta
5. ~~**Variar el tipo de calidad**~~ ✅
6. ~~**Fartlek y cuestas**~~ ✅
7. **Bloque persistido** — periodización de verdad e historia. ← siguiente
8. **Fases** — solo si aparecen datos que las justifiquen.

Lo que queda del motor de calidad: **rectas** (unos 6×20 s al final de un rodaje fácil) y
**progresivos**. Los dos son baratos, pero ninguno cambia el cuadro como lo hacía la rotación.

Del 1 al 4 es el motor de volumen; 5 y 6 el de calidad. **Los seis están hechos.**

Una consecuencia de modelar el fartlek y las cuestas: `IntervalSpec.Rep` distingue repeticiones
**por distancia o por tiempo**. Nadie corre "400 m" en un fartlek, corre un minuto fuerte, y
modelarlo en metros obligaba a inventar una distancia que el atleta no va a medir. El reloj traduce
cada caso a su meta de WorkoutKit.

## Lo que el motor no puede saber

Un patrón que se repite: **la app deduce la intención del atleta de sus datos, y la intención no
está en los datos.**

| Síntoma | Lo que no se puede deducir |
|---|---|
| `WeekStatus` tuvo que existir | "descansé a propósito" vs. "no pude" |
| "esta semana quiero más/menos días" | tu disponibilidad de la semana que viene |
| "Sugerir" solo sabe escalar tu pasado | a dónde quieres llegar, y desde qué punto |
| El plan se reescribe solo | qué decidiste tú y qué calculó él |

`WeekStatus` fue el primer parche: un campo donde declaras algo que ningún sensor ve.

La regla que separa lo que se pregunta de lo que no:

| | ¿Observable? | Ejemplos |
|---|---|---|
| **Hechos del pasado** | ✅ | cuánto corriste, si hubo un parón, tu tirada más larga |
| **Intención y capacidad** | ❌ | cuántos días *puedes*, qué *quieres*, si tienes cuestas cerca |

**Preguntar un hecho es hacerle trabajo al atleta que la app ya hizo.** Por eso la entrevista
(`AthleteIntake`, etapa 1 ✅) son **tres** preguntas y no diez:

1. **¿Qué buscas?** — mejorar marca / terminar la distancia / mantener la forma. Cambia la
   estructura de la semana, no el tono de los textos.
2. **¿Cuántos días puedes entrenar?** — los que *puedes*, no los que entrenaste.
3. **¿Tienes dónde hacer cuestas?** — con su definición pegada, porque "cuesta" significa cosas
   muy distintas según a quién le preguntes.

Y una cuarta **condicionada**: los km semanales, solo si no hay historial en Salud. Es el único caso
en que el motor está ciego del todo — sin historial no hay base, ni carga crónica, ni techo.

> **Por qué no se pregunta "de dónde vienes".** Es un hecho del pasado, no una intención: Salud lo
> tiene. Y sobre todo, **el techo por carga crónica ya lo codifica**, como número continuo en vez
> de como etiqueta — quien vuelve de un parón tiene el crónico bajo y el techo lo frena solo.
> Preguntarlo daría dos mecanismos para lo mismo y habría que decidir cuál manda.

> **Por qué no se pregunta el historial de lesiones.** Es la que más obviamente "debería" estar,
> pero no hay forma calibrada de usar la respuesta. Sería pedir un dato para guardarlo en un cajón,
> con la falsa sensación de que el plan se individualiza. Entra cuando sepamos qué hacer con ella.

Va en **un solo flujo** con lo observado, no en un botón aparte. Tenerlos separados no era solo
confuso de nombre: la entrevista y el viejo "Sugerir plan" **escribían los dos `daysPerWeek`**, y
ganaba el último que corriera. Es exactamente el fallo que este documento advierte de "dos
mecanismos para lo mismo obligan a decidir cuál manda" — cometido al aplicarlo. El historial ahora
solo propone lo que sabe mejor que tú (cuánto volumen has sostenido); los días los declaras en un
único sitio.

Las respuestas son, literalmente, la cabecera del bloque persistido: **la entrevista produce el
bloque**. Etapas 2 (congelar la semana en curso) y 3 (el bloque) siguen pendientes; ahí es donde
ajustar los días de una semana concreta deja de ser un parche y pasa a ser editar una semana.

## Lo que NO vamos a hacer, y por qué

- **Cambiar el 8% por otro número inventado.** Sustituir una constante sin calibrar por otra no es progreso. El ACWR al menos sale de tus datos.
- **Variedad por variedad.** Rotar sesiones para que "el cuerpo no se acostumbre" no tiene respaldo. Variar por disfrute sí, y se dice con esas palabras.
- **Fases antes que descargas.** Las fases son lo más visible y lo menos sostenido; las descargas al revés.
- **Prescribir sin datos.** Si un número no sale de la evidencia ni de tus datos, se documenta como sin calibrar en vez de presentarse como certeza. Ver *Umbrales sin calibrar* en [pendientes.md](pendientes.md).

## Fuentes

- Buist et al. (2008), *No effect of a graded training program on the number of running-related injuries in novice runners: a randomized controlled trial* — ECA, 532 novatos.
- Damsted et al. (2018), revisión sistemática sobre la regla del 10%: evidencia insuficiente.
- Nielsen et al. (2014), *Excessive progression in weekly running distance and risk of running-related injuries*.
- [Bosquet et al. (2007), *Effects of tapering on performance: a meta-analysis*](https://www.semanticscholar.org/paper/Effects-of-tapering-on-performance:-a-Bosquet-Montpetit/a41517ab5fa06b92568b861e2b1aa32b3003d214).
- Seiler, sobre distribución polarizada de intensidad (80/20).
- Gabbett (2016) sobre ACWR, y la crítica metodológica de Impellizzeri et al. (2020).
