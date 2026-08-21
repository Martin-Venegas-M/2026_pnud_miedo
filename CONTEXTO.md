# Contexto del proyecto

Documento de orientación. Léelo antes de tocar nada; es el punto de entrada.
`PLAN.md` es el plan de ejecución por fases y tiene el detalle de cada decisión;
este archivo dice **dónde estamos, cómo está armado y qué trampas ya pisamos**.

Última actualización: 21 de agosto de 2026.

---

## 1. Qué es esto

Tipologías de miedo al delito a partir de la **ENUSC 2025**, para una
consultoría del PNUD. El análisis agrupa a las personas con un MCA seguido de
clustering jerárquico (HCPC), sobre ocho variables construidas a partir de la
encuesta.

**La ENUSC no tiene "olas".** Tiene versiones anuales de la misma encuesta, cada
una sobre una muestra distinta. No se sigue a las mismas personas en el tiempo.
Comparar dos años es comparar dos estimaciones independientes de la población. No
usar la palabra "ola" en la página.

## 2. Por qué este repo existe

Es un reinicio limpio de `/Users/mar/Work/Github/2025_pnud_miedo`, hecho el 10 de
agosto de 2026.

**El hallazgo:** en las preguntas de opción múltiple, la alternativa "ninguna
medida de seguridad" venía en una columna con sufijo `_na`, y el código la
trataba como **no aplica**. Como el modelado exigía casos completos, esas
personas quedaban fuera. No al azar: sub-representaba hogares de NSE bajo y con
menos miedo. El modelo se construía sobre poco más de la mitad de la muestra.

**Lo que importa del hallazgo no es el error, es que tardó dos años en
aparecer.** El análisis se validaba mirando distribuciones de frecuencia, una
variable a la vez. Ese tipo de revisión muestra si una variable quedó rara, pero
no muestra qué le pasó a cada persona **entre** un paso y el siguiente. Por eso
el pipeline nuevo produce logs de transición, no solo marginales.

Detalle con cifras en el repo viejo: `CONTEXTO.md §4.9` y
`web/reporte-contrafactual.qmd`.

## 3. Estado actual

**Rama de trabajo: `refactor/targets`.** No se ha mergeado a `main`.

| | |
|---|---|
| Muestra (tras filtro Kish) | 55.796 |
| Casos que entran al modelo | 49.503 (88,8%) |
| Soluciones calculadas | 4, 5 y 6 grupos |
| Solución que se venía reportando | 5 grupos |
| Targets en el DAG | 81 |

**Las ocho decisiones metodológicas originales están cerradas, y la de la base
también.** Lo que queda abierto es sobre qué reportar, no sobre cómo calcular, y
necesita al equipo:

1. **Cuántos grupos se reportan.** No hay criterio estadístico que decida: el %
   de inercia no sirve porque las tres soluciones se construyen sobre el mismo
   MCA. Lo que sí hay es la lectura sustantiva de la pestaña Primeras lecturas:
   las tres son el mismo árbol cortado a tres alturas, con **seis bloques
   terminales**, y la de 6 no agrega un nivel de miedo sino un **eje de
   protección** transversal.
2. **Cómo se llaman los grupos.** Hoy son `C1` a `C6`.
3. **Dos casos anotados y sin resolver**, los dos en recuadros de Pipeline: las
   **982 personas** en la categoría "de día y de noche" que solo tenían un
   momento aplicable, y las **7.880** que esperan un delito violento y uno no
   violento y quedan contadas como no violento, porque esa rama del `case_when`
   se evalúa primero.

**La base se cerró el 21 de agosto de 2026: se reporta la ponderada.** Todas las
tablas de la página estiman población con el diseño muestral. La muestral, que
es la que devuelve `catdes()`, sobrevive solo en la matriz de perfiles, para
poder contrastar con los informes anteriores. La decisión entró al registro.

### Fases del plan

| Fase | Estado |
|---|---|
| 0 Preparación, 1 Refactor a targets, 2 Inventario, 3 Decisiones | Cerradas |
| 4 Medición de variantes | No iniciada, y probablemente ya no haga falta |
| F5.3 Tablas descriptivas, F5.4 Página | Hechas |
| F5.1 Gold y testbed, F5.2 Reparar `analysis/` | Pendientes |

**`analysis/` sigue roto y quedó desbloqueado.** Los dos scripts que hay ahí son
del repo viejo y no corren. Ya se puede repararlos: D2 y D4 están cerradas, así
que sus vectores de variables no van a volver a cambiar. Ojo con el rename (§5).

## 4. Cómo está armado

```
_targets.R        el DAG (81 targets)
R/                las funciones, cargadas con tar_source()
web/              las 8 páginas .qmd
docs/             el sitio renderizado, es lo que sirve GitHub Pages
docs/archivo/     versiones congeladas de la página
output/logs/      los CSV de log del pipeline, versionados
output/tables/    tablas del entregable (xlsx + csv)
input/data/       la base original y los intermedios
PLAN.md           plan de ejecución por fases, con el detalle de cada decisión
```

El pipeline va: seleccionar → construir índices → construir las variables sin
índice → categorizar → rescatar la no respuesta → etiquetar → preparar el modelo
→ MCA → HCPC → pegar clusters → variables secundarias.

**Cuatro de las ocho variables del modelo no pasan por un índice.** Las dos de
`comgen` se cuentan directo sobre su batería, porque sus ítems no admiten el
código 85 y el denominador no varía; `perper_delito` y `comper_gasto` se arman
cruzando respuestas del cuestionario. Las cuatro se construyen en un solo paso,
`datos_sin_indice`.

Cada target de datos tiene un **target de log pareado** que compara entrada y
salida. Los logs viven en `output/logs/` y se versionan: son el registro
diffeable de qué cambió entre corridas. `git diff` sobre `marginales.csv` dice
más que cualquier `.RDS`.

## 5. Convenciones que hay que respetar

### Nomenclatura de variables

Cuatro familias, y la distinción importa:

| Familia | Qué es |
|---|---|
| **Originales** | Las de la ENUSC sin transformar |
| **Fuente** | Las que construimos. Cuatro índices `_pct` con su `_cat`; dos `_cat` de `comgen` que se cuentan directo sobre la batería y no tienen `_pct`; más `perper_delito` y `comper_gasto` |
| **De clusters** | `clusters_4`, `clusters_5`, `clusters_6` |
| **Secundarias** | `cfg$VARS_SEC`. No entran al modelo; describen los grupos |

Las ocho que entran al modelo están en **`cfg$VARS_MODELO`**. Hubo dos renames
en agosto de 2026, y cualquier código o análisis viejo que uses hay que
actualizar:

| Antes | Ahora |
|---|---|
| `VARS_REC_TERCIL`, variables en `_rec_tercil` | `VARS_MODELO`, variables en `_cat` |
| `comgen_per_pct_cat`, `comgen_com_pct_cat` | `comgen_per_cat`, `comgen_com_cat` |

El segundo se hizo cuando esas dos dejaron de pasar por un índice: el `_pct` del
nombre prometía un porcentaje que ya no existe.

Cuidado con **"dimensión"**: nombra tanto las cuatro dimensiones teóricas
(`emper`, `perper`, `comper`, `comgen`) como los ejes del MCA.

### Reglas del pipeline

1. **`replace(x, which(cond), valor)`, nunca `if_else()` sobre vectores
   etiquetados.** `if_else()` corre sobre `vctrs` y descarta el atributo `labels`
   en silencio; el error aparece mucho después y no apunta a la causa.
2. **Un solo `cfg`**, como target, y `R/config.R` contiene exactamente lo que lo
   construye. Ahí viven los parámetros, los vectores de variables, `CORTES` y
   los siete diccionarios (`INDICES`, `BATERIAS`, `ETIQUETAS`, `ETIQUETAS_SEC`,
   `PATRONES`, `CODIGOS_COMGEN`, `SECUNDARIAS`).

   **Los dos cortafuegos.** `targets` rastrea dependencias por target y no por
   campo, así que cualquier cambio a `cfg` invalidaría todo lo que lo lea,
   incluido el HCPC. Por eso `cfg_n_clases` y `cfg_vars_modelo` existen como
   targets de una línea: son los dos únicos campos que la zona cara del DAG lee
   directo. Al cambiar `cfg` se recalculan, devuelven lo mismo y la cascada
   muere ahí. Si agregás un campo que el modelo lea directo, necesita el mismo
   tratamiento.
3. **Las aserciones no se comentan** para que el pipeline avance. Si algo falla al
   calibrar, revisar la diferencia *es* el trabajo.
4. **El log es un target derivado, no un efecto secundario.** Nada de `message()`
   que se pierde en consola.
5. **Reportar la pérdida muestral** en cada paso que descarte casos.
6. **Verificar el supuesto antes de construir sobre él.** Antes de tratar un
   código especial de una forma nueva, confirmar con datos qué significa.
7. **Bucles a `purrr`, aserciones a `rlang::abort()`.** Los `for` que acumulan
   columnas sobre un data frame se escriben como `purrr::reduce(..., .init =)`.
   Los mensajes usan viñetas (`x =` qué pasó, `i =` por qué importa) y no llevan
   el nombre de la función, que `abort()` ya reporta.

### Reglas de la página

**Ningún número nace en un chunk.** Todo sale de un target o de los CSV de log.
El `.qmd` lee, pivotea y formatea.

**Al cerrar una decisión, barrer la página entera.** Los rastros quedan en más
lugares de los que uno recuerda: los sellos `motivo_provisional` de los targets,
los recuadros que anuncian tipos de aviso que ya no existen, las entradas del
glosario, y los `grep()` de los `.qmd` que filtran por sufijo de variable. Un
rename de variables puede vaciar una pestaña entera sin que nada falle: pasó con
`_rec_tercil` a `_cat`, que dejó la subpestaña de índices categorizados sin
tablas. Conviene un `stopifnot()` donde un filtro por nombre pueda quedar vacío.

**Las tablas del entregable pasan por `limpiar_tabla_descriptiva()`** (redondeo,
descarte de filas vacías solo si `frq == 0`). La página lee los targets directo,
así que **no** recibe esa limpieza: hay que redondear y filtrar en el `.qmd`. Ya
pasó una vez que salieran 170 filas `NA 0 NA`.

### Estilo de los docstrings

**Sin referencias históricas.** Nada de `PLAN.md`, ni nombres de scripts del repo
anterior, ni fases (`F5.3`), ni secciones (`§4.0`), ni decisiones por código
(`D1`, `D2`). Quien abre una función hoy no tiene ese contexto y no debería
necesitarlo. Se limpiaron 64 referencias en agosto de 2026; no reintroducirlas.

**Prioridad a qué hace la función hoy.** Si además encarna una decisión de fondo,
va en `@details`, contada **por su sustancia y no por su etiqueta**: en vez de
"D1 aplicada", explicar que las columnas `_na` quedan fuera porque registran
"ninguna medida", que es una respuesta y no una medida más.

### Estilo de prosa

El usuario reescribió la primera versión de la página. Los patrones:

- **Sin rayas.** Paréntesis, dos puntos, coma o guión simple. También
  `no respuesta`, no `no-respuesta`.
- **Sin dramatismo ni construcción retórica.** Enunciar el hecho y seguir.
- **Relato factual antes que justificación inferida.** No inventar por qué se
  decidió algo: contar qué pasó.
- **Más mecánica del dato**, menos caracterización abstracta.
- **Primera persona plural**: "miremos", no "mire".
- **Vocabulario del dominio directo**: "informante Kish", "columna dummy".

## 6. Trampas ya pisadas

Esta sección vale más que el resto. Todas costaron tiempo.

### Al diagnosticar con scripts sueltos

**`zap_labels()` significa cosas opuestas según el paquete.**
`haven::zap_labels()` saca el atributo y conserva los valores.
`sjlabelled::zap_labels()` **convierte a `NA` los valores etiquetados**. Si ambos
están cargados gana el último del `search()` path. Usar siempre
`haven::zap_labels()` calificado. Sin esto una columna entera aparece como 100%
`NA` y uno concluye que el pipeline destruyó los datos.

**`. %in% c(85, 88, 99)` sobre `haven_labelled` falla** si `sjlabelled` no está
cargado. El patrón `replace(., which(. %in% code), NA)` depende del orden de
`library()`.

**`table()` sobre `haven_labelled` falla.** Envolver en `haven::zap_labels()`.

### Al escribir la página

**`align = NULL` explícito a `kbl()` no es lo mismo que omitirlo.** kableExtra
escribe `style="NAposition: sticky"` en los `<th>`, CSS inválido que rompe el
encabezado fijo. Pasar `align` solo si tiene valor.

**Quarto lanza R desde `web/`**, así que `.Rprofile` de ahí tiene que fijar
`RENV_PROJECT` **antes** de sourcear `../renv/activate.R`. Sin eso renv concluye
que el proyecto es `web/` y arranca una biblioteca vacía adentro. Y el almacén de
targets hay que apuntarlo explícitamente (`_setup.R` lo hace).

**No referirse a filas por posición en la prosa.** Escribí dos veces "las dos
primeras filas" cuando el caso estaba en la segunda y la tercera. Derivar los
valores de los datos, no de la posición.

**Un subdirectorio dentro de `docs/` sobrevive al render**, así que el archivado
funciona. Verificado.

### Del instrumento

**Los índices se construyen con rangos posicionales y eso trunca baterías en
silencio.** `P_INSEG_LUGARES` tiene 16 ítems y el índice usa 11; el criterio está
documentado ahora, pero el patrón puede repetirse en una versión nueva de la
encuesta.

**Hay dos formatos para los códigos especiales**, y confundirlos fue el origen
del rediseño. En las baterías son un valor de la columna; en las preguntas de
opción múltiple son **columnas propias**, y ahí `_NA` (respuesta sustantiva),
`_NS` y `_NR` (no respuesta) son estructuralmente idénticas. Solo las etiquetas
las distinguen.

**El `96` ("Sin dato") está declarado en casi todas las variables y aparece muy
rara vez.** Todo `case_when` sobre códigos especiales debe contemplarlo.

**Las baterías bajo filtro reexpresan la pregunta filtro.** Los catorce ítems de
`perper_p_delito_pronostico_*` se preguntan solo a quien contestó "sí" a
`perper_p_expos_delito`. Al describirlos por cluster, la categoría sin dato de
los catorce da exactamente la misma cifra que el "No" de la pregunta filtro
(88,0% en C1 contra 44,8% del total, o sea +43,2 pp), así que una tabla ordenada
por diferencia abre con once filas idénticas. No es un error de cálculo: es el
salto del cuestionario contado catorce veces. Cualquier tabla que recorra
columnas originales tiene que decidir qué hace con eso.

### Del modelo

**`HCPC()` cuesta ~22 minutos y dos tercios son desperdicio.** Se llama una vez
por solución y **los tres árboles son idénticos**: el árbol depende solo del MCA,
el número de grupos es solo dónde se corta. Verificado que `cutree()` reproduce
exactamente la misma partición (cambian solo las etiquetas, porque `HCPC` las
reordena por el primer eje).

Arreglarlo implica replicar por fuera el reordenamiento y la llamada a
`catdes()`. **No se hizo** porque el DAG completo se re-corre pocas veces al año.
Pero si se retoma la Fase 4 (comparar variantes), conviene hacerlo antes: tres
variantes serían 66 minutos.

El costo base tampoco es trivial: 49.503 personas son 1.225 millones de
distancias, ~9,1 GB. Medido, la escala se degrada 2-3× respecto de lo cuadrático
por presión de memoria.

**`tar_outdated()` sobreestima siempre, y no sirve para estimar el costo.** Es
un análisis estático: propaga la invalidación por el grafo sin ejecutar nada, así
que **no puede saber si un target va a devolver el mismo valor**. Cualquier
cambio a `cfg` lo muestra invalidando el DAG entero, `hcpc` incluido. Medido: en
un refactor de estilo listó los 76 targets y al correr `mca` y `hcpc` se
saltaron, con la corrida completa en 2 minutos. Sirve para decidir cuándo
preguntar antes de lanzar, no para predecir cuánto va a tardar.

**Lo que sí revela el costo real** es correr y después mirar `tar_progress()`:
qué quedó en `skipped`. El corte por hash está verificado sobre este DAG.

**Los cortafuegos aguantan, medido dos veces.** Al agregar un diccionario a
`cfg` (`BATERIAS`), `tar_outdated()` volvió a listar los 81 targets, `mca` y
`hcpc` incluidos. En la corrida real los dos salieron `skipped`: 30 recalculados
y 51 saltados en 8 min 27 s. Vale la pena mirar el archivo de progreso mientras
corre (`_targets/meta/progress`, una línea por target con su estado) en vez de
esperar al final: ahí se ve si el corte funcionó a los pocos segundos.

**Refactorizar funciones no cuesta nada.** Verificado en un proyecto `targets`
aislado: comentarios, docstrings, formato y mover una función de archivo **no
invalidan**; renombrar una variable local sí, pero la cascada se corta enseguida
porque el valor de retorno no cambia. Agregar aserciones es barato.

**Antes de correr, verificar función por función contra el almacén.** Recalcular
una función reescrita y compararla con su target guardado cuesta segundos y da
más información que `tar_outdated()`. En el refactor a `purrr` atrapó tres
errores que no habrían llegado a la corrida: un paréntesis de cierre huérfano al
reemplazar un `stopifnot`, un `list_c(ptype=)` que falla con columnas
`haven_labelled`, y un `character(1)` que sobrevivió a la conversión y que
`map_chr` pasaba como argumento extra a la función.

**Al borrar un target, buscar quién lo nombra.** Pasó dos veces: `logs_transformacion`
consolida trece targets de log por nombre, y al borrar uno el error aparece recién
cuando el pipeline llega ahí, que puede ser veinte minutos después. Un `grep` del
nombre borrado sobre `_targets.R`, `R/` y `web/` cuesta nada.

**`catdes()` falla al autoimprimirse** con estos datos, por `v.test` infinitos.

**El `v-test` no sirve para ordenar a este tamaño de muestra.** En más de la mitad
de las filas se sale de escala y quedan todas empatadas, justo entre las
asociaciones más fuertes. La página ordena por diferencia en puntos porcentuales
(`lift_pp = Mod/Cla - Global`) y conserva el `v-test` como referencia.

**La numeración de los grupos no es comparable entre corridas.** El modelo la
reasigna cada vez.

## 7. Decisiones cerradas, en una línea cada una

El detalle está en `PLAN.md` y en el registro de la página.

1. **Se descarta la dimensión perceptual general** (`pergen`), tras las
   discusiones sobre las soluciones de 2024.
2. **"Ninguna medida" es respuesta, no dato faltante.** Entra con 0% de adopción.
   Es el hallazgo que motivó el rediseño.
3. **"Otro delito" separado de "no sabe qué delito".** Recupera 78 casos; es
   corrección de validez, no de tamaño.
4. **Qué situaciones componen el espacio público:** todas las clasificables como
   tal. Quedan fuera las referidas al propio barrio y los espacios de uso propio.
5. **"No sabe" cuenta como no adhesión** en los índices `_pct`: se queda en el
   denominador. Convención conservadora, decidida a propósito.
6. **Quienes no responden la pregunta filtro de victimización se mantienen
   fuera.** Es no respuesta genuina, sin respuesta sustantiva escondida.
7. **Cómo se cortan los índices:** por lo que la variable significa, con el cero
   siempre como categoría propia. Tres métodos declarados en `cfg$CORTES`. Los
   dos de `comgen` no pasan por un índice: se cuentan directo sobre la batería,
   porque sus ítems no admiten 85 y el denominador no varía. Reemplazó a los
   terciles.
8. **No respuesta en los índices secundarios:** se prorratea, con un mínimo de la
   mitad de la batería. Conserva la métrica de suma.

## 8. Lo que queda pendiente

**Sustantivo, para el equipo:** las cuatro de §3. Cuántos grupos se reportan,
cómo se llaman, qué base se reporta, y qué hacer con los dos casos anotados.

De esas, la de la **base** es la más urgente, porque afecta las cifras que se
citan y hoy la página resuelve distinto en distintos lugares: la matriz de
perfiles muestra las dos en tabset, la tabla "Qué distingue a cada grupo" es
muestral y la de "Perfil de los grupos" es ponderada. Ninguna de las dos tablas
dice cuál usa.

**Técnico, en orden de utilidad:**

1. **Reparar `analysis/`** (F5.2). Está desbloqueado.
2. **Gold y testbed** (F5.1). Anclar sobre los CSV de log, que ya llevan varias
   corridas de historia. No versionar `.RDS` como gold: no es diffeable.
3. **Optimizar el HCPC**, si se retoma la comparación de variantes.
4. **Mergear `refactor/targets` a `main`.** Todo el trabajo vive en la rama.

**Anotado y no resuelto:**

- El ítem 14 de `P_MOD_ACTIVIDADES` ("Hacer otra actividad") sigue excluido del
  índice sin criterio escrito. Bajo impacto, mismo estándar pendiente.
- `spec_patrones()` declara `pergen`, que ya no existe en el pipeline. La
  función sí se usa (`tabla_variables_originales()` la consume); lo vestigial es
  esa entrada.
- `tabla1_variables_originales` emite un warning de `separate()`
  (`Expected 2 pieces. Additional pieces discarded in 4 rows`). Es preexistente y
  su salida no cambia, pero nadie lo atendió.
- Los `.xlsx` figuran modificados en cada corrida aunque su contenido no cambie:
  `openxlsx` escribe un timestamp dentro del zip. El registro versionado real es
  el `.csv` hermano, que sí es diffeable. Al revisar un diff, mirar los CSV.
- `renv` quedó con `snapshot.type: "all"` (286 paquetes) porque el escáner de
  dependencias no ve los paquetes declarados en `tar_option_set(packages =)`. El
  arreglo liviano es un `_dependencies.R` que los liste.
- Las rutas `output/tables/2025` están escritas literales en `_targets.R`, y
  `cfg` no tiene `PATH_TABLES`. Cambiar `cfg$ANIO` no bastaría para procesar otra
  versión de la encuesta.

## 9. La página

Ocho pestañas en `web/`, renderizadas a `docs/`:

**Introducción · Metadata · Pipeline · Univariados · Solución actual ·
Primeras lecturas · Decisiones pendientes · Glosario**

El propósito la distingue de la anterior: comunica **los resultados y las
decisiones que los producen**. Por eso la pestaña central es Pipeline y no la
solución.

**Solución actual** tiene, además del biplot y los mapas de cluster, el
**perfil de los grupos** y la **matriz de perfiles**.

El perfil son tres tablas por solución, una por familia de variables:
originales, fuente y secundarias. Todas ponderadas, con las mismas seis
columnas (grupo, variable, respuesta, diferencia en pp, % en el grupo, % en el
total). Las de fuente y secundarias van ordenadas por diferencia; la de
originales va en el orden del cuestionario, batería por batería y con las
alternativas de cada ítem en el orden en que las declara el instrumento, que
viene del target `orden_categorias_orig`. Ordenar 67 columnas por diferencia
dejaba los ítems de una misma batería desperdigados. Las **67 columnas
originales**
salen de `cfg$INDICES` más `cfg$CODIGOS_COMGEN`, y se rotulan con
`etiquetas_originales()`, que aísla el ítem descartando el prefijo y el sufijo
común de cada batería. **No usa `cfg$PATRONES`**: el separador de `perper`
incluye "en su" y trunca "Robo en su vivienda" a "Robo". El cruce ponderado de
esas 67 por las tres soluciones es el paso más caro fuera del modelo, 5 min.

La matriz de perfiles pone las 24 categorías del modelo en filas, los grupos en
columnas, y en la celda la diferencia en puntos porcentuales contra el total. Se
presenta en tabsets anidados, solución afuera y base adentro. **Es el único
lugar de la página donde conviven las dos bases**, muestral y ponderada: el
resto es todo ponderado. Azul es diferencia positiva y
naranja negativa, que es la convención de los corrplot; va al revés de `PAL_DIM`,
donde el azul nombra la dimensión emocional, y está anotado en el código.

**Primeras lecturas** es una pestaña aparte, escrita por un LLM y **declarada
como tal en un callout al comienzo**. Recorre los seis grupos de la solución más
fina y después mira la estructura entre soluciones. Las afirmaciones
comparativas ("el grupo más joven") llevan una aserción cada una, de modo que si
el modelo se recalcula y alguna deja de ser cierta, la página no compila en vez
de seguir afirmándola. Al escribirlas ya apareció una que era falsa.

Diseño idéntico al de la página anterior (`cosmo`), con el azul cambiado a negro
para distinguirlas de un vistazo. Tablas con `kableExtra`; **nada de tablas
interactivas**, las de la página anterior no fueron bien recibidas.

`docs/archivo/2025-08-terciles/` conserva la versión construida con terciles,
congelada, con una banda en cada página. Ahí está el diagnóstico completo de por
qué se cambió el criterio de corte, que se sacó de la página vigente para no
arrastrar la historia.

Para renderizar: `cd web && quarto render`. Requiere que el DAG esté corrido.
