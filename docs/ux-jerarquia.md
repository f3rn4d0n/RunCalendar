# Jerarquía de pantallas: qué va arriba y por qué

> **Qué es este documento.** Los criterios con los que se decide el orden y el peso visual de lo que
> se muestra. Existe para que el siguiente cambio de UI no sea una discusión desde cero, y para que
> quien lo haga —persona o IA— sepa qué se decidió ya y con qué argumento.
>
> El *qué* de cada pantalla está en el [README](../README.md); esto es el *por qué está en ese
> orden*.

## El atleta que tenemos en la cabeza

**No todos los atletas quieren lo mismo, ni al mismo nivel.** Uno abre la app para ver cuánto lleva
corrido esta semana; otro quiere entender por qué su VO₂max no sube. Los dos son usuarios legítimos
y **la pantalla no puede optimizarse para el segundo**, que es la tentación natural de quien la
construye.

De ahí la regla que gobierna todo lo demás:

> **Lo relevante siempre a la vista. Lo completo, para quien lo busca.**

Y su corolario, que es el que cuesta aplicar:

> **Esconder no es la solución; lo que hay que quitar es la competencia por la primera mirada.**

Bajar algo en la página, agruparlo con lo suyo o plegarlo son formas de que deje de competir sin
dejar de existir. Borrarlo o meterlo tres niveles adentro es otra cosa, y casi nunca hace falta.

## Los cinco criterios

**1. Una pantalla, una pregunta.** Si una pantalla responde tres preguntas distintas, se nota como
desorden aunque cada pieza esté bien. Antes de mover nada, escribe la pregunta que responde — y
comprueba que otra pantalla no la responda ya.

**2. Lo accionable pendiente manda.** Una tarea sin hacer es lo más relevante que puede haber; la
misma tarea ya cumplida es ruido en un informe. La misma sección puede ir arriba o abajo según su
estado.

**3. Las entradas no van en medio del informe.** Pedir datos entre dos bloques de lectura rompe el
hilo. O encabezan (si urgen) o cierran (si no).

**4. Un tema, un bloque.** Información del mismo asunto repartida por la pantalla obliga a
reconstruirla mentalmente. Es la causa más frecuente de "esto se ve desacomodado".

**5. Lo avanzado baja o se pliega, no desaparece.** Y si con bajarlo basta, no se pliega: un toque
de más también cuesta.

## Caso trabajado: la pestaña **Progreso**

### Qué estaba mal

Once secciones en este orden: readiness de tus carreras · recuperación · check-in · review
dominical · precisión de la calibración · tendencia HRV · carga · resumen · gráficas · readiness por
distancia.

| Criterio | Qué fallaba |
|---|---|
| Una pregunta | Mezclaba "¿cómo estoy hoy?", "¿cómo evoluciono?" y "¿para qué estoy listo?" |
| Accionable | El check-in estaba fijo en el puesto 3, hecho o no |
| Entradas | Check-in y review, en medio del informe |
| Un tema, un bloque | Recuperación en **cuatro** pedazos; readiness partido en dos, con nueve secciones en medio |
| Avanzado | El VO₂max pesaba igual que los kilómetros de la semana |

### La decisión que lo desbloqueó

**Hoy ya responde "¿cómo estoy hoy?"** con el anillo de recuperación. Así que *Progreso* no tiene
que competir con eso: responde **"¿dónde estoy y hacia dónde voy?"**.

Con eso, la recuperación puede bajar de puesto sin perder nada — su titular vive en otra pantalla —
y el resumen sube, que es lo que orienta.

Es el criterio 1 haciendo el trabajo: la pregunta no se decidió mirando esta pantalla, sino mirando
**qué preguntas responden ya las otras**.

### El orden resultante

```
1. Check-in de hoy      ← solo si está pendiente (y el aviso real vive en *Hoy*)
2. Resumen              ← de lo accionable a lo avanzado, sin plegar
3. ¿Listo para…?        ← tus carreras + por distancia, juntas
4. Recuperación y carga ← estimado + precisión + tendencia + ACWR
5. Gráficas             ← volumen y ritmo
6. Registrar            ← check-in ya hecho + review dominical
```

### Lo que la primera versión hizo mal

Se probó en el teléfono y salieron cuatro cosas. Las apunto porque son errores **de criterio**, no
descuidos, y se pueden repetir:

**Plegué tres filas.** El resumen ya estaba arriba y ordenado de lo esencial a lo avanzado; meterle
un "Más detalle" encima cobró un toque por tres filas. Es el criterio 5 incumplido por su autor:
*baja **o** pliega*, no las dos. Si son pocas filas, el orden basta.

**Una fuente distinta por accidente.** `MetricRow` no fijaba tipografía y heredaba, así que dentro
del `DisclosureGroup` se veía distinta. Un componente reutilizable que hereda estilo se ve diferente
según dónde caiga: **fija el estilo en el componente**, no en el contenedor.

**El `footer` de una sección se lee como el encabezado de la siguiente.** En una pantalla de muchas
secciones seguidas, la nota al pie no deja claro de quién habla. Van dentro (`SectionNote`).

**"¿Acierta el modelo?" estaba detrás de la tendencia.** Mide el **estimado**, no la tendencia. Un
bloque agrupado no basta: dentro también hay orden, y cada cosa va pegada a lo que juzga.

### Dos decisiones que conviene no deshacer sin pensarlo

**El resumen se ordena, no se pliega.** Volumen de la semana, promedio y carrera más larga primero;
VO₂max y FC en reposo al final de la sección. La jerarquía se aplica **por fila** —el problema nunca
fue la sección, era que dentro de ella todo pesaba igual— pero con seis filas el orden ya basta.
Plegarlas fue el error de la primera versión.

**Los avisos viven donde se abre la app.** El check-in estaba al fondo de *Progreso*, donde no lo ve
nadie. Ahora está **pegado al anillo de recuperación en Hoy**, que es la pantalla diaria — y pegado
al anillo y no como tarjeta propia, porque es lo que alimenta ese número y porque *Hoy* ya tiene dos
avisos: un tercero la convertiría en una lista de reproches. En línea, además: navegar a otra
pantalla para pulsar uno de cinco botones es más fricción que el propio registro.

Lo que queda al fondo de *Progreso* deja de ser un CTA y pasa a ser un **acceso permanente**, que
ahí está bien.

**Las gráficas no se pliegan.** Estar al final ya es jerarquía suficiente: quien no las busca no
llega, y a quien sí las busca un plegado solo le cuesta un toque de más. Plegar todo lo avanzado
sería sobrediseñar — el criterio 5 dice *baja o pliega*, no las dos cosas.

### Una métrica, dos preguntas, dos sitios

El HRV aparece **dos veces** en *Progreso* y no es duplicación:

| Dónde | Qué pregunta responde | Forma |
|---|---|---|
| Recuperación | ¿Puedo apretar **hoy**? | Diario, con su ruido |
| Tu evolución | ¿Me estoy **adaptando**? | Promedio semanal, ~6 meses |

Es el mismo patrón que los kilómetros: el número de la semana en *Resumen*, la curva en *Tu
evolución*. **Antes de mover una métrica "que está repetida", comprueba si las dos instancias
responden la misma pregunta.** Si no, moverlas juntas empeora las dos.

## Antes de mover una pantalla

1. ¿Qué pregunta responde? ¿La responde ya otra?
2. ¿Hay algo accionable? ¿Cambia de sitio según esté hecho o pendiente?
3. ¿Hay entradas mezcladas con lectura?
4. ¿Hay un tema repartido en trozos?
5. ¿Compite lo avanzado con lo esencial? ¿Basta con bajarlo?

Y al terminar: **verlo en el teléfono**. Las pruebas de este repo cubren el motor, no la experiencia,
y los tres últimos defectos de UI aparecieron abriendo la app, no en CI.
