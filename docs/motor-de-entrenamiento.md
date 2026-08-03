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
| **Progresión semanal** | `base × 1.08` hasta topar con tu meta | La "regla del 10%" es **tradición**: un ECA con 532 novatos no encontró diferencia en lesiones entre un programa graduado y uno estándar. Lo que sí aparece es que saltos **>30%** aumentan lesiones | Techo por **ACWR** en vez de un porcentaje fijo, y escalones que se achican al acercarse a tu techo |
| **De dónde sale la base** | Suma **móvil de 7 días** de lo que corriste | — | Base estable (media de 28 días o máximo de las últimas 3 semanas) |
| **Semanas de descarga** | **No existen.** Solo `WeekStatus.deload` manual, y solo pausa la medición | **Principio**: sin recuperación planificada la sobrecarga deja de adaptar. La cadencia exacta (cada 3ª o 4ª) es convención | Cada 4ª semana: volumen −40%, intensidad intacta — la misma regla del taper |
| **Techo de carga** | Ninguno más allá del 8% y los topes por sesión | **ACWR** (agudo 7 d / crónico 28 d) es mejor gobernador que un % fijo, con la crítica metodológica de Impellizzeri et al. encima | Cablearlo al plan |
| **Taper** | ✅ 2 semanas, volumen −40/50%, intensidad intacta | **Sólido** (Bosquet et al., meta-análisis de ~50 estudios) | Sin cambios |

> **El bloqueador de verdad.** La base sale de tu propio output de la semana pasada, así que una
> descarga al 60% hace que el motor crea que bajaste de forma y arranque desde ahí. **El motor pelea
> activamente contra cualquier periodización.** Arreglar esto es prerrequisito de todo lo demás, y
> es barato.

### Motor de calidad

| | Hoy | Evidencia | Propuesta |
|---|---|---|---|
| **Distribución de intensidad** | Pesos de volumen; la prueba solo fija que la calidad no se lleve más del 50% | El **80/20** está **sólido** (Seiler y otros) — pero se define por *tiempo* o *sesiones*, no por km | Medirlo como toca antes de presumir de 80/20 |
| **Tipos de sesión** | Series, tempo, fácil, larga. Las series salen de una fórmula de km → 400/600/800 m | **Sólido**: repeticiones cortas y largas no dan el mismo estímulo. Solo 5×800 deja fuera velocidad y umbral | Variar el tipo de calidad **a lo largo del bloque** |
| **Cuestas, rectas, progresivos, ritmo de carrera** | **No existen** | Cuestas y rectas: **principio** (fuerza específica, economía). Ritmo de carrera: **sólido** para especificidad | Al menos ritmo de carrera cerca de la meta |
| **Fartlek vs. series en pista** | No hay fartlek | A intensidad y duración iguales el estímulo es **equivalente**. Cambiar el envoltorio no adapta más — eso es el **mito** de la "confusión muscular" | Sí, pero **por adherencia**: el disfrute predice la constancia y la constancia predice el resultado. Y se dice así en la app, sin fingir fisiología |

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
| **¿Alimenta el plan?** | **No.** `AssessWorkloadUseCase` y `RecoveryCalibration` viven solo en Progreso | — | El ACWR es el primer puente entre las dos mitades de la app |
| **Calibración por RPE** | Ajusta la estimación de recuperación con tu feedback | — | Mismo camino, más adelante |

---

## Lo que ya está bien y no hay que tocar

- **El taper.** Es lo mejor sostenido del motor y ya está implementado como dice la evidencia.
- **Los topes por sesión.** Una serie es por repeticiones, no un balde de km.
- **Carreras inscritas y víspera protegida.** Reglas de colocación, sin números inventados.
- **Avisar en vez de inflar.** Cuando el volumen no cabe, el motor lo dice en lugar de meter sesiones enormes. Es la postura correcta y conviene mantenerla en todo lo que sigue.

## Orden propuesto

1. **Base estable** — que una descarga no hunda la semana siguiente. *Prerrequisito de todo.*
2. **Descargas cada 4ª semana** — lo de mayor respaldo por lo que cuesta.
3. **Techo por ACWR** — cablear lo que ya se calcula.
4. **Escalones decrecientes** al acercarse al techo personal.
5. **Variar el tipo de calidad** dentro del bloque.
6. **Fartlek y cuestas** como presentación alterna, etiquetado como lo que es.
7. **Bloque persistido** — periodización de verdad e historia.
8. **Fases** — solo si aparecen datos que las justifiquen.

Del 1 al 4 es el motor de volumen; 5 y 6 el de calidad; son separables.

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
