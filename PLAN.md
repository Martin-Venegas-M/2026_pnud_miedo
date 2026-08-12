# Plan de ejecución — tipologías de miedo al delito (PNUD 2026)

Refactor del pipeline a `targets` + decisiones sustantivas pendientes.

Documento escrito para ser **ejecutado por un agente**. Los números están
verificados sobre los datos reales (ENUSC 2025, `N = 55.796` tras
`filter(Kish == 1)`); el Anexo A los lista para que no haga falta recalcularlos.

- **Fecha de redacción:** 11 de agosto de 2026
- **Estado del repo:** limpio, commit `54006c5`
- **Rama de trabajo:** crear `refactor/targets` desde `main`

---

## 0. Cómo usar este documento

1. **Las fases son secuenciales.** No se avanza sin cumplir el criterio de
   aceptación de la anterior.
2. **Antes de empezar cada fase, presentar un resumen breve y esperar el visto
   bueno del usuario.** Cinco a diez líneas, no un informe:
   - qué se va a hacer, en una o dos frases;
   - qué archivos se crean, modifican o eliminan;
   - qué decisiones del plan se aplican (y cuáles explícitamente **no**);
   - cómo se va a verificar al terminar.

   Es un checkpoint, no una formalidad: es la oportunidad de corregir el rumbo
   antes de que el trabajo esté hecho. Si durante la fase aparece algo que
   cambia ese resumen, avisar en el momento, no al final.
3. **Los puntos marcados `[ABIERTO]` no se resuelven por cuenta propia.** Se
   pregunta al usuario y se espera respuesta.
4. **La Fase 1 es un refactor que NO cambia resultados.** Ver §F1.0: es la
   instrucción más importante de todo el documento.
5. **Las aserciones no se comentan para que el pipeline avance.** Si algo falla,
   revisar la diferencia *es* el trabajo.
6. Sobre la API de `targets`: este plan especifica la arquitectura, no la
   sintaxis exacta. Verificar los detalles de la API contra la documentación del
   paquete antes de escribir código.

---

## 1. Por qué existe este repo

Reinicio limpio de `/Users/mar/Work/Github/2025_pnud_miedo`, hecho el 10 de
agosto de 2026 al descubrir que el MCA reportado perdía ~45% de la muestra por
tratar como dato faltante una respuesta que en realidad es sustantiva.

**El hallazgo, en una frase:** en preguntas de opción múltiple del tipo "¿cuál(es)
de estas medidas ha adoptado?", la opción *"ninguna"* es una respuesta válida
(0% de adopción), no una ausencia de dato. El repo viejo la codificaba con el
mismo código `85` que usa para "no aplica" genérico, y el paso de modelado
convertía todo `85` en `NA` antes de exigir casos completos. Resultado: esas
personas quedaban fuera del modelo, y no al azar — la exclusión sub-representaba
hogares de NSE bajo y con menos miedo, justo el perfil que más importa.

Detalle con cifras en el repo viejo: `CONTEXTO.md §4.9` y
`web/reporte-contrafactual.qmd`.

**La consecuencia metodológica que ordena todo este plan:** antes de tratar
cualquier código especial (`85`/`88`/`96`/`99`) de una forma nueva, hay que
confirmar con datos reales qué significa. No se infiere del nombre de la
variable ni de que el código existente lo haga así.

**El fix original ya está aplicado** en este repo y verificado: la muestra que
entra al MCA es de 49.431 casos (88,6%), que coincide exactamente con el
escenario "85 conservado como respuesta válida" que el repo viejo había medido
como contrafactual. Este plan aborda lo que ese fix no cubrió.

### Por qué el refactor, y no solo los arreglos

El pipeline actual valida sus resultados con llamadas sueltas a `sjmisc::frq()`
y comentarios que anotan lo observado:

```r
sjmisc::frq(enusc$comgen_per_pct)              #* Hay varianza, 0 NA's
sjmisc::frq(enusc$comgen_per_pct_rec_tercil)   #* Se mantienen 0 NA's
```

Ambas observaciones son correctas, y entre las dos hay un bug grave (ver D2) que
ninguna puede mostrar: **un marginal antes y un marginal después no dicen nada
sobre el flujo entre ellos.** Esto sí lo dice, con los datos reales de hoy:

```
comgen_per_pct       T1       T2       T3
     0                1        0        0
    10            18563     2373        0     <- misma respuesta, dos terciles
    20                0    14867        0
    30                0     1324     8782     <- otra vez
```

Los dos hallazgos sustantivos de la auditoría salieron de cruzar antes contra
después, no de mirar distribuciones. El objetivo del refactor es convertir eso
en un artefacto de primera clase, producido automáticamente en cada paso, en vez
de algo que alguien hace a mano cuando ya sospecha.

Además, los comentarios `#*` son **expectativas escritas a mano que hoy no
fallan cuando dejan de ser ciertas**. Congeladas como aserción, sí.

---

## 2. Reglas de la casa

Vienen de trampas ya pisadas. El costo de violarlas está documentado.

1. **`replace(x, which(cond), valor)`, nunca `if_else()` sobre vectores
   etiquetados** (`haven` / `sjlabelled`). `if_else()` corre sobre `vctrs` y
   descarta el atributo `labels` en silencio. El error que produce después
   (`to_label()` como no-op, `MCA()` fallando con un mensaje que no apunta a la
   causa) es muy caro de diagnosticar.
2. **Un solo `cfg`**, ahora como target. Ver §F1.3.
3. **Las aserciones no se comentan** para que el pipeline avance.
4. **Las variantes exploratorias son ramas del DAG**, no scripts paralelos
   copiados. *(Modificada por este plan: antes era "script paralelo con sufijo".)*
5. **Reportar la pérdida muestral explícitamente** en cada paso que descarte
   casos.
6. **Verificar el supuesto antes de construir sobre él.**
7. **El log es un target derivado, no un efecto secundario.** *(Nueva.)* Nada de
   `message()` que se pierde en la consola: cada reporte es un objeto
   materializado, hasheado y comparable entre corridas.

### Deuda que NO hay que heredar del repo viejo

Su lista de decisiones abiertas (`CONTEXTO.md §7`) contiene bugs dormidos
específicos de aquel código: truncamientos de `separate()`, etiquetas sin
espacio, el typo `stata`/`strata`. Son bugs, no patrones. Tampoco asumir que hace
falta un sitio Quarto ni estructura de carpetas por ola.

---

## 3. Estado verificado del pipeline actual

Cuatro scripts en `processing/`, dos en `analysis/`, `config.R` con el `cfg`, y
helpers en `processing/helpers/`.

**Corre de punta a punta:** `1_select.R` → `2_recode.R` → `3_add_clust.R` →
`4_add_vars.R`.

**Verificado correcto** (no tocar al refactorizar):

- El pegado de clusters (`3_add_clust.R:89-113`) es correcto: las tres
  soluciones coinciden caso a caso con `results_all`, y las 49.431 filas con
  cluster son exactamente las que entraron al MCA. Los 6.365 `NA` son los
  excluidos. `rph_id` no tiene duplicados.
- Las etiquetas de variable y de valor quedan aplicadas en el archivo final.

**No corre:** `analysis/descriptivos.R` y `analysis/descriptivos_iniciales.R`.
Ver Fase 5.

---

## 4. Variables: nomenclatura y tipología

### 4.0 Nomenclatura (fijada por el usuario, 11 de agosto de 2026)

**Vocabulario único del proyecto.** Usarlo en código, tablas, logs y entregables.
Cuatro familias:

| Familia | Qué es | Ejemplos |
|---|---|---|
| **Variables originales** | Las de la ENUSC tal como vienen. Se nombran **igual que en `enusc_original`**, y en algún lugar se registra cómo las renombramos nosotros | `P_INSEG_LUGARES_1` → `emper_p_inseg_lugares_1` · `MEDIDAS_PERRO` → `comgen_medidas_perro` |
| **Variables fuente** | Las **recodificaciones** de las originales: los índices `_pct`, sus versiones categorizadas, y las que se categorizan de otra forma | `emper_ep_pct`, `emper_ep_pct_rec_tercil`, `perper_delito`, `comper_gasto` |
| **Variables de clusters** | Las que produce el modelo | `clusters_4`, `clusters_5`, `clusters_6` |
| **Variables secundarias** | Sociodemográficas, victimización, índices de desórdenes e incivilidades, fuentes de información | `cfg$VARS_SEC` |

> **Cambio de significado — leer con atención.** Hasta el 11 de agosto de 2026
> este plan usaba "variables fuente" para las **crudas**. A partir de la
> nomenclatura de arriba, esas son las **originales**, y "fuente" pasa a
> significar lo contrario: las recodificadas. Todo el documento quedó
> actualizado. Si aparece "fuente" con el sentido viejo en código o comentarios,
> es residuo: corregirlo.
>
> El parámetro `source.cols` de `create_var_pct()` **no** es residuo: ahí
> "source" es relativo ("las columnas de las que se construye esta"), no una
> familia de variables.

**Pendiente de nombre.** `cfg$VARS_REC_TERCIL` quedó mal llamado por partida
doble: contiene `perper_delito` y `comper_gasto`, que no son terciles, y "REC"
es vocabulario viejo. Es el subconjunto de variables fuente que entra al MCA.
Renombrarlo (`VARS_FUENTE_MODELO` o similar) es tarea de código, no de este
documento; hacerlo en un commit propio, sin mezclar con otro cambio.

**Mapeo original → nuestro nombre.** Lo produce `seleccionar_variables()` con sus
`rename_with()` por dimensión, así que es derivable del código y no hay que
mantenerlo a mano. Debe exponerse como target y acompañar a las tablas de
variables originales (§F5.3).

### 4.1 Tipología de las variables originales

**Base conceptual del refactor.** Verificada sobre la base original el 11 de
agosto de 2026. El eje que la define es **dónde viven los códigos especiales**:
como valor dentro de la columna, o como columna propia. Confundir los dos casos
es exactamente el error de §1.

| Tipo | Estructura | Códigos especiales | Baterías |
|---|---|---|---|
| **A** — batería de ítems | Una columna por ítem | **Como valor** en cada columna | `P_INSEG_*` (20 cols) · `P_MOD_ACTIVIDADES` (14) · `P_DESORDENES` (8) · `P_INCIVILIDADES` (7) |
| **B** — respuesta única | Una columna | **Como valor** | `P_EXPOS_DELITO` · `COSTOS_MEDIDAS` · `P_FUENTE_INFO_*` (3) |
| **C** — marque todas | Una columna `0`/`1` por opción | **Como columna propia** | `MEDIDAS` (8 + 3) · `VECINOS_MEDIDAS` (7 + 3) · `P_DELITO_PRONOSTICO` (11 + 3) |

### 4.1.1 Escalas y códigos por tipo (verificado)

| Batería | Tipo | Valores sustantivos | Códigos especiales presentes |
|---|---|---|---|
| `P_INSEG_LUGARES_*`, `P_INSEG_OSCURO_*`, `P_INSEG_DIA_*` | A | `1`–`4` (Likert: Muy inseguro → Muy seguro) | `85`, `88`, `99` (`96` declarado, ausente) |
| `P_MOD_ACTIVIDADES_*` | A | `1`/`2` (Sí/No) | `85`, `88`, `99` |
| `P_DESORDENES_*`, `P_INCIVILIDADES_*` | A | `1`–`5` | `88`, `99` — **sin `85`** |
| `P_EXPOS_DELITO` | B | `1`/`2` | `88`, `99` |
| `COSTOS_MEDIDAS` | B | `1`–`5` | `85`, `88`, `96`, `99` |
| `P_FUENTE_INFO_*` | B | `1`–`9` | `77`, `88`, `99` |
| `MEDIDAS_*`, `VECINOS_MEDIDAS_*` | C | `0`/`1` | `96` en columna; `85`→`_NA`, `88`→`_NS`, `99`→`_NR` como columnas |
| `P_DELITO_PRONOSTICO__*` | C | `0`/`1` | `96` en columna; `77`→`__77`, `88`→`__88`, `99`→`__99` como columnas |

**El tipo A no es dummy.** `emper` son escalas Likert de 4 puntos; `comper` es
binaria pero codificada `1`/`2`, no `0`/`1`. Los únicos dummies `0`/`1` reales
son los del tipo C. Esto es lo que determina `success.cats`: `c(1, 2)` para
`emper`, `1` para `comper`.

**Dentro del tipo A el conjunto de códigos varía.** `emper` y `comper` traen
`85`; `desordenes` e `incivilidades` no. Un tratamiento uniforme del tipo A debe
declarar los códigos por batería, no asumirlos.

### 4.1.2 `perper_delito` es tipo B **y** tipo C a la vez

`P_EXPOS_DELITO` es tipo B (valores `1,2,88,99`), pero `P_DELITO_PRONOSTICO_*`
son 14 columnas dummy donde `__77`, `__88` y `__99` son **columnas**.

Esto **explica D3 mecánicamente**: la categoría 5 hace `if_any()` sobre
`pronostico_{77, 88, 99}`, tres columnas tipo C estructuralmente idénticas. El
código no puede distinguir "otro delito" de "no sabe" porque en los datos tienen
exactamente la misma forma.

### 4.1.3 Por qué el error de §1 era fácil de cometer

En el tipo C, `_NA` ("ninguna"), `_NS` ("no sabe") y `_NR` ("no responde") son
**columnas hermanas, estructuralmente indistinguibles**. Nada en el dato dice que
la primera es una respuesta sustantiva y las otras dos son ausencia de respuesta.

Cualquier código que trate "las columnas especiales" de forma uniforme conflaciona
una respuesta con dos no-respuestas. Por eso la distinción tiene que estar
**declarada**, no inferida.

Detalle práctico: la misma estructura usa **dos convenciones de nombre distintas**
— `MEDIDAS_NA`/`_NS`/`_NR` frente a `P_DELITO_PRONOSTICO__77`/`__88`/`__99`.

### 4.1.4 El `96` es un agujero latente en todas partes

`96` ("Sin dato") está declarado en las etiquetas de casi todas las variables
pero aparece en los datos muy rara vez (1 caso en `COSTOS_MEDIDAS`, 1 en
`MEDIDAS_NA`). Es exactamente el agujero de `comper_gasto` (ver F2.1).

**Regla:** todo `case_when` sobre códigos especiales debe contemplar `96`, o
tener un `TRUE ~` explícito que no lo mande a `NA` por descuido.

### 4.1.5 Cómo se usa esta tipología en el refactor

Se materializa como un target `spec_variables` que declara, por batería: tipo,
ítems, códigos especiales presentes, cómo se expresan (valor o columna), valores
sustantivos esperados, y `success.cats` cuando corresponda.

Tres consecuencias:

1. **`construir_indices_pct()` despacha según el tipo** en vez de hardcodear el
   tratamiento. El tipo C necesita leer columnas hermanas; el tipo A necesita leer
   valores. Hoy esa diferencia está implícita y repartida.
2. **Las aserciones se derivan del spec.** Si el conjunto de valores observado no
   coincide con el declarado, falla nombrando la batería. Es la regla #6 hecha
   estructura, y cubre la deriva de instrumento entre olas mucho mejor que
   `dic_items.R`, que hoy compara textos de etiqueta.
3. **La tipología es el esquema del inventario de la Fase 2.** El CSV del
   inventario tiene una fila por combinación de batería y código, y su columna
   "decisión" hereda el tipo. No son dos ejercicios: es el mismo.

---

## FASE 0 — Preparación

### F0.1 Rama

Crear `refactor/targets` desde `main`. Todo el trabajo de este plan va ahí.

### F0.2 Entorno

- Inicializar `renv` (disponible: 1.2.3; R 4.5.2). **No es opcional**: un DAG que
  se invalida por una actualización de `FactoMineR` es peor que no tener DAG.
- Instalar `targets`. Evaluar `tarchetypes` si se necesita branching estático.
- `renv::snapshot()` con todos los paquetes que hoy usan los scripts:
  `tidyverse`, `haven`, `tidylog`, `rlang`, `sjlabelled`, `sjmisc`, `sjPlot`,
  `janitor`, `glue`, `srvyr`, `openxlsx`, `scales`, `FactoMineR`, `factoextra`.

### F0.3 Qué se versiona ahora

**RESUELTA y ejecutada (Fase 0, `b4eb745`): se usa el almacén de targets.**
Se conserva acá el razonamiento porque fija qué es el registro versionado del
proyecto.

La decisión previa fue versionar los `.RDS` del pipeline. Al mudarse al almacén
de targets, esos archivos dejan de existir como tales: los objetos viven en
`_targets/objects/`, uno por target.

Recomendación:

| Ruta | Acción | Motivo |
|---|---|---|
| `_targets/objects/` | `.gitignore` | Caché reconstruible; cambia en cada corrida |
| `_targets/meta/` | **versionar** | Texto plano, una línea por ejecución: es el log de ejecución, ya diffeable |
| `output/logs/*.csv` | **versionar** | Los reportes de transformación (§F1.5). Es el registro sustantivo |
| `input/data/original/*.rds` | dejar como está | Ya versionado, es el insumo |
| `input/data/proc/`, `output/models/` | dejar como están **hasta cerrar Fase 1** | Son la referencia contra la cual se valida el refactor |

Consecuencia a tener presente: el registro versionado del proyecto pasa a ser
**el log, no los datos**. Los datos se reconstruyen con `tar_make()`.

### Criterio de aceptación

`renv.lock` existe y `tar_make()` de un `_targets.R` mínimo corre sin error.

---

## FASE 1 — Refactor a `targets`

**Esta fase no cambia ningún resultado.**

### F1.0 La instrucción más importante

**NO arreglar ningún bug durante el refactor.** D1 a D5 quedan intactas. El
pipeline refactorizado debe reproducir **exactamente** los números actuales,
incluidos los que sabemos que están mal.

Motivo: si el refactor cambia la arquitectura *y* los resultados a la vez, no hay
forma de saber cuál de los dos cambios produjo una diferencia. Los arreglos vienen
en la Fase 3, de a uno, con el log mostrando el delta de cada uno.

Los binarios comiteados en `54006c5` son la **referencia** contra la cual se
valida. Esa es su función en esta fase.

### F1.1 Estructura de archivos

```
_targets.R              # definición del DAG
R/                      # funciones, cargadas con tar_source()
  config.R              # construir_config()
  seleccion.R
  indices.R
  categorizacion.R
  codigos_especiales.R
  modelo.R
  vars_secundarias.R
  etiquetas.R
  reportes.R            # el sistema de log
output/logs/            # CSV derivados de los targets de log
```

`processing/*.R` y `processing/helpers/*.R` se eliminan al terminar la fase, no
antes: sirven de referencia mientras se traduce.

### F1.2 Nomenclatura de targets

- Datos: `datos_<etapa>` (`datos_seleccionados`, `datos_pct`, …)
- Logs: `log_<etapa>`, mismo sufijo que el target de datos que reportan
- Modelo: `mca`, `hcpc`, `soluciones`
- Especificaciones: `spec_<cosa>`

### F1.3 `cfg` como target

La regla #2 se conserva, pero `cfg` pasa a ser un target:

```r
tar_target(cfg, construir_config())
```

Así, cambiar un parámetro invalida lo que corresponde. `construir_config()`
reemplaza el `config.R` actual, **menos las rutas de artefactos intermedios**,
que se las come targets. Sobreviven: `ANIO`, `N_CLASES`, `CLUSTER_A_SACAR`, los
vectores de variables (`VARS_REC_TERCIL`, `VARS_SEC`), el diseño muestral
(`SVY_IDS`, `SVY_STRATA`, `SVY_WEIGHTS`), y la ruta del archivo original.

`ANIO` se queda como valor literal dentro de `construir_config()`. Nada de
variable de entorno por ahora — no hay segunda ola que lo justifique. Si entra
2024 (pregunta P1), reevaluar.

El archivo de entrada se declara con `format = "file"` para que un cambio en los
datos originales invalide el DAG completo.

### F1.4 Las funciones del pipeline

Una función por **decisión que podría estar equivocada**. Ese es el criterio de
granularidad: no una por variable, no una por script.

#### Selección

| Función | Qué hace | Reemplaza | Decisión |
|---|---|---|---|
| `leer_enusc(archivo)` | Lee el `.rds` original | `1_select.R:36` | — |
| `filtrar_muestra(datos)` | `filter(Kish == 1)` | `1_select.R:58` | Qué informante por hogar |
| `seleccionar_variables(datos, cfg)` | Selección por dimensión, prefijos `emper_`/`perper_`/`comper_`/`comgen_`, `clean_names()` | `1_select.R:52-91` | Qué entra al análisis |

**Nota sobre `seleccionar_variables()`:** el código actual tiene un
`rename(comper_costos_medidas = comgen_comper_costos_medidas)` marcado
`#! FIX MANUAL` (`1_select.R:91`). Es consecuencia de que los regex de dimensión
se solapan (`"MEDIDAS|VECINOS"` captura `COSTOS_MEDIDAS`). **Conservar el
comportamiento**, pero dejar una aserción que verifique que las columnas
resultantes son las esperadas, para que un solapamiento nuevo falle en vez de
producir un nombre raro.

#### Construcción de índices

| Función | Qué hace | Reemplaza | Decisión |
|---|---|---|---|
| `construir_indices_pct(datos, spec)` | Las 6 llamadas a `create_var_pct()`: `emper_ep`, `emper_barrio`, `emper_casa`, `comper`, `comgen_per`, `comgen_com` | `2_recode.R:82-96`, `107-111`, `121-130` | **D1** — qué columnas entran en `source.cols` |
| `construir_perper_delito(datos)` | El `case_when` de 5 categorías | `2_recode.R:97-106` | **D3** — cómo se arma la categoría 5 |
| `construir_comper_gasto(datos)` | El `case_when` de gasto | `2_recode.R:112-120` | El `96` sin cubrir |
| `marcar_no_respuesta_comgen(datos)` | Pasa a `NA` `comgen_*_pct` cuando la persona marcó NS/NR | `2_recode.R:154-167` | Tratamiento de NS/NR en opción múltiple |

`spec` es la lista `rec_vars` de `2_recode.R:42-78` — el mapeo de columnas originales
por índice. Pasa a ser un target propio (`spec_indices`) porque **es donde vive
D1 y D4**: cambiarla debe invalidar todo lo de abajo.

**`spec_variables` es el otro target de especificación**, y deriva de la
tipología de §4: declara por batería el tipo (A/B/C), los ítems, los códigos
especiales presentes, cómo se expresan (valor o columna), los valores
sustantivos esperados y `success.cats`. `construir_indices_pct()` **despacha
según el tipo** en lugar de hardcodear el tratamiento: el tipo C lee columnas
hermanas, el tipo A lee valores. Hoy esa diferencia está implícita y repartida
entre `create_var_pct()` y los `case_when` de `2_recode.R`.

De `spec_variables` se derivan además las **aserciones de estructura**: si el
conjunto de valores observado en una batería no coincide con el declarado, falla
nombrando la batería. Es la regla #6 hecha estructura, y cubre la deriva de
instrumento entre olas mejor que `dic_items.R`, que compara textos de etiqueta.

`create_var_pct()` (hoy en `functions.R:474`) se conserva como helper de
`construir_indices_pct()`. **No se toca su lógica en esta fase** — el `88`/`99`
en el denominador (D6) es una convención deliberada del proyecto: se conserva.

**Ojo, `marcar_no_respuesta_comgen()` usa hoy `if_else()`** (`2_recode.R:158-167`).
Ahí es inocuo porque `comgen_per_pct` ya es numérica pura, pero al reescribirla
usar `replace(..., which(...), ...)` por consistencia con la regla #1.

#### Categorización y códigos especiales

| Función | Qué hace | Reemplaza | Decisión |
|---|---|---|---|
| `categorizar_indices(datos, metodo)` | Convierte las `_pct` en categorías | `2_recode.R:169` | **D2** — `ntile` vs. cortes sustantivos |
| `recuperar_codigos_especiales(datos, spec)` | Reimputa `85`/`88`/`99` en las variables recodificadas cuando todos los ítems originales traían ese código | `2_recode.R:172-181`, `197-223` | Tratamiento de códigos especiales |
| `etiquetar(datos, etiquetas)` | Aplica etiquetas de variable y de valor | `2_recode.R:238-256`, `4_add_vars.R:206-224` | — |

`categorizar_indices()` recibe el método como **parámetro**, no lo hardcodea. Es
lo que hace barata la Fase 4: comparar variantes de D2 es cambiar un argumento en
el DAG, no copiar un script.

Las etiquetas (`helpers/labels.R` y `4_add_vars.R:129-203`) pasan a un target
`spec_etiquetas`.

#### Modelo

| Función | Qué hace | Reemplaza | Decisión |
|---|---|---|---|
| `preparar_datos_mca(datos, vars)` | Pasa `85`/`88`/`99` a `NA`, saca las categorías 4 y 5 de `perper_delito`, convierte a factores con `to_label()` | `3_add_clust.R:46-75` | Qué se considera dato faltante |
| `filtrar_casos_completos(datos, vars)` | Solo filtra. **Sin reportar** | `3_add_clust.R:80` | Qué se exige completo |
| `ajustar_mca(datos, id_col)` | Corre `FactoMineR::MCA()` | parte de `mca_hcpc()` (`functions.R:358`) | — |
| `ajustar_hcpc(mca, n_clases)` | Corre `FactoMineR::HCPC()` con `consol = FALSE` | parte de `mca_hcpc()` | — |
| `pegar_clusters(datos, soluciones)` | `left_join` + `factor()` con etiquetas `C1..Cn` | `3_add_clust.R:89-113` | — |

**Dos cambios de diseño acá, ambos deliberados:**

**(a) `mca_hcpc()` se parte en dos.** Hoy es una sola función llamada tres veces
(`cfg$N_CLASES = 6:4`), o sea que **corre el MCA tres veces sobre los mismos
datos** para producir el mismo resultado. Separadas, el MCA es un target que corre
una vez y el HCPC ramifica sobre `n_clases`. Es más rápido y, sobre todo,
estructuralmente correcto: deja explícito que la solución de clusters depende del
MCA y no al revés.

Conservar `consol = FALSE`: es lo que hace el resultado determinista (no depende
de semilla). Verificado contra el gold del repo viejo caso por caso.

**(b) `filtrar_casos_completos()` NO reporta.** En la conversación previa se había
diseñado un `reportar_drop_na()` que filtraba e informaba a la vez. Bajo targets
eso viola la regla #7: el reporte sería un `message()` que se pierde. Se separa en
función pura de filtrado + target de log derivado (§F1.5).

#### Variables secundarias

| Función | Qué hace | Reemplaza | Decisión |
|---|---|---|---|
| `construir_indices_secundarios(datos)` | Índices de desórdenes e incivilidades | `4_add_vars.R:35-58` | **D5** — prorrateo vs. `na.rm = TRUE` |
| `construir_vars_info(datos)` | Las cinco `info_*` | `4_add_vars.R:61-102` | Tratamiento de `77`/`88`/`99` |
| `recodificar_sociodemograficas(datos)` | `rph_nivel_rec`, `rph_edad_rec`, `enc_region_rec` | `4_add_vars.R:105-125` | — |

`construir_vars_info()` usa hoy `if_else()` sobre columnas etiquetadas
(`4_add_vars.R:70-78`). Ahí no se pierde nada porque las `info_*` nacen numéricas,
pero al reescribir aplicar la regla #1.

#### Helpers que sobreviven sin cambios

`create_var_pct()`, `tab_frq1()`, `tab_frq2()`, `format_tab_excel()`,
`pre_proc_excel()`, `plot_mca()`.

**`tab_frq1()` y `tab_frq2()` tienen argumentos por defecto que leen del entorno
global** (`data = enusc`, `svyobj = enusc_svy`). Bajo targets eso rompe o, peor,
lee el objeto equivocado. Hacer los argumentos obligatorios.

#### Helpers que se eliminan

- `gen_vct()` (`functions.R:443`): depende de que exista un `enusc` global.
  Incompatible con targets y sin uso real. Eliminar.
- `plot_cluster()` (`functions.R:427`): está rota (recibe `obj` pero por dentro
  usa `clust`, que no existe en su entorno) y no la llama nadie. Eliminar.
- `helpers/gen_metadata_recode.R`: fragmento sin cabecera que depende de
  `rec_vars` y `enusc` en el ambiente, no lo sourcea nadie, y usa `separate()`
  con el patrón frágil `"(\\?|en su|en el|edificio.)\\s*"` — el mismo que
  truncaba "Robo en su vivienda" → "Robo " en el repo viejo. **No portar.** Si
  después hace falta metadata, se rehace.

### F1.5 El sistema de log

Es el corazón del refactor. Tres funciones de reporte y una regla de conexión.

#### `reportar_transformacion(antes, despues, vars, etiqueta)`

El reporte principal. Se ejecuta después de **cada** target de datos. Tres
bloques:

| Bloque | Contenido |
|---|---|
| **Forma** | Filas antes/después; columnas agregadas, eliminadas y modificadas |
| **Marginales** | Distribución de cada variable en `vars`, antes y después. Es lo que hoy dan los `frq()` sueltos |
| **Transiciones** | Matriz origen × destino por variable recodificada |

**El bloque de transiciones es el que no existe hoy y el que justifica todo esto.**
Requisitos no negociables:

- `NA` es una **fila y una columna explícitas** del cruce, nunca filtrada. El
  hallazgo de §1 fue de casos que se movieron *hacia* `NA`; un cruce que descarta
  `NA` los vuelve invisibles.
- Se reporta también cuando origen y destino tienen distinto número de
  categorías (es el caso normal: `_pct` continua → tercil).

#### `reportar_perdida(antes, despues, vars, etiqueta)`

Para los pasos que descartan casos. Por variable, dos cantidades, y la distinción
es el punto:

- `n_na`: casos con `NA` en esa variable. **Suma más que el total eliminado**,
  porque un caso puede tener `NA` en varias.
- `n_solo`: casos que **solo** esa variable elimina.

**`n_solo` es una cota superior, no una estimación de recuperación.** Dice cuánto
se recuperaría si el arreglo eliminara *todos* los `NA` de esa variable. Cuando el
arreglo ataca solo una sub-parte —que es lo habitual— la recuperación real es
mucho menor.

> Caso concreto, ya ocurrido: `perper_delito` tenía `n_na = 2.539` y
> `n_solo = 2.182`, y el plan predijo que D3 recuperaría 2.182 casos. Recuperó
> **78**, porque 2.389 de esos `NA` son de la categoría 4 (no-respuesta en la
> pregunta filtro) y D3 solo toca la categoría 5. Ver D3.

Antes de convertir un `n_solo` en predicción, **descomponer el `NA` por su
origen**: qué categoría, qué columna original, qué código. Solo la parte que el
arreglo efectivamente ataca cuenta.

Lógica de referencia (ya probada contra los datos actuales: devuelve 49.431,
idéntico a `drop_na()`):

```r
faltan     <- is.na(datos[vars])
n_por_caso <- rowSums(faltan)

detalle <- tibble::tibble(
    variable = vars,
    n_na     = colSums(faltan),
    n_solo   = colSums(faltan & n_por_caso == 1)   # ESTA es la única con NA
)
```

Cómo se lee:

| Patrón | Lectura |
|---|---|
| `n_na` alto, `n_solo` casi igual | Causa independiente; arreglarla rinde lo que promete |
| `n_na` alto, `n_solo` bajo | Comparte casos con otras; arreglarla sola rinde poco |
| `n_na` bajo, `n_solo` ≈ 0 | Irrelevante para el N; sus casos ya los elimina otra variable |
| Suma de `n_solo` vs. total | Cuánta superposición hay entre causas |

Señales que ameritan parar: una variable con `n_na` ≈ total eliminado (el modelo
está definido por una sola pregunta); `n_solo = 0` con `n_na` alto (origen de
no-respuesta compartido); aparece una variable que antes no estaba (cambió el
instrumento).

#### `reportar_composicion(datos, eliminados, vars_sec)`

`reportar_perdida()` mide **magnitud**, no **composición**. El hallazgo de §1 fue
de composición: la pérdida no era solo grande, era **sesgada**. Un reporte de
magnitud habría mostrado "45%" y no habría bastado.

Cruza los casos eliminados contra `cfg$VARS_SEC` (NSE, educación, edad, región) y
compara su perfil con el de los que quedan.

Se corre **una vez por cada decisión adoptada** en la Fase 3, no una sola vez al
final.

#### Cómo se conectan al DAG

Cada target de datos tiene un target de log **pareado**:

```r
tar_target(datos_pct, construir_indices_pct(datos_seleccionados, spec_indices)),
tar_target(log_pct,   reportar_transformacion(
    antes    = datos_seleccionados,
    despues  = datos_pct,
    vars     = c("emper_ep_pct", "emper_barrio_pct", ...),
    etiqueta = "indices_pct"
))
```

Y un target consolidador que junta todos los logs y escribe
`output/logs/*.csv`. Esos CSV **se versionan siempre** — son el registro
sustantivo del proyecto y lo que hace que `git diff` responda "¿qué cambió?" con
`comgen_per tercil 1: 18.563 → 24.569` en vez de `Bin 4529489 → 4531102 bytes`.

#### El arco de los tres usos

Los reportes tienen tres vidas, y conviene tenerlo presente al diseñarlos:

1. **Informa** — durante el desarrollo se leen con ojos. Es la validación humana
   formalizada que reemplaza a los `frq()` sueltos.
2. **Compara** — en la Fase 4, el diff entre variantes.
3. **Protege** — en la Fase 5, congelados como expectativa y convertidos en
   aserción.

Por eso `reportar_perdida()` lleva un parámetro `max_perdida` que **se deja en
`NULL` hasta la Fase 5**. Calibrar un umbral ahora sería fijarlo contra números
que la Fase 3 va a cambiar a propósito.

### F1.6 Saneamiento que targets obliga

- Sacar los `rm(list = ls())` del inicio de cada script. Incompatible con un
  pipeline de funciones.
- Los `library()` en bloque de cada script pasan a `tar_option_set(packages = )`.
- Argumentos por defecto que leen globales → obligatorios (§F1.4).

### Criterio de aceptación de la Fase 1

Todos los siguientes, sin excepción:

1. `tar_make()` corre limpio desde cero.
2. `tar_read(datos_recodificados)` tiene **las mismas columnas con los mismos
   valores** que `input/data/proc/2025/enusc_2_recode.RDS` del commit `54006c5`.
   Comparar columna por columna, no el archivo completo.
3. Ídem para el equivalente de `enusc_3_add_clust.RDS` y `enusc_4_add_vars.RDS`.
4. La asignación de clusters coincide caso a caso con la actual: 49.431
   asignados, 6.365 `NA`, y las etiquetas `C1..Cn` en el mismo orden.
5. `reportar_perdida()` sobre el paso del MCA reproduce exactamente la tabla del
   Anexo A.2.
6. Los CSV de log existen y son legibles.
7. `tar_visnetwork()` (o equivalente) muestra el DAG completo sin targets
   huérfanos.
8. **Inventario de traducción completo.** Toda función que §F1.4 manda conservar
   está en `R/`, y toda la que manda eliminar no está. Verificar con una lista
   explícita, no a ojo.
9. `renv::status()` reporta el proyecto sincronizado.

**Si algún número difiere, el refactor está mal.** No ajustar la referencia: hay
un error de traducción que encontrar.

> **Por qué existe el punto 8.** En la primera ejecución de este plan, §F1.4
> listaba seis helpers a conservar y se portó uno. Los criterios 1–7 pasaron
> igual, porque todos verifican que **el pipeline** reproduce los números, y
> ninguno verifica el **inventario de lo que el plan mandó conservar**. El
> criterio 7 no puede atrapar un helper que todavía no tiene consumidor. La
> omisión recién apareció en la Fase 5, cuando `analysis/` los necesitó.

---

## FASE 2 — Inventario de códigos

**Estado: ABIERTA.** Cierra formalmente el hallazgo de §1.

Producir un CSV con una fila por combinación de variable original y código
especial: `variable | código | N | significado | decisión | justificación`.

Cubrir `85`, `88`, `96`, `99` y `77` en todas las baterías. Los N están en el
Anexo A. Lo que falta, y es el punto del ejercicio, es la **columna de decisión,
escrita**.

### F2.1 Hechos verificados que el inventario debe recoger

**Solo `MEDIDAS` y `VECINOS_MEDIDAS` tienen columna "ninguna" explícita.**
Verificado sobre la base original: no existen columnas `_NA`/`_NS`/`_NR` en
ninguna otra batería. El hallazgo de §1 está acotado a dos variables.

**El `85` a nivel de ítem es masivo y ambiguo.** No confundirlo con el `85` de
§1 — son dos cosas distintas. Este es el que trae cada ítem individual de una
batería, y `create_var_pct()` lo excluye del denominador, que es correcto *si*
significa "no tengo Metro en mi ciudad". Pero también puede significar "dejé de
usar el Metro por miedo", que es literalmente la variable dependiente. **Con
estos datos no son distinguibles.**

> **Recomendación: mantener el tratamiento actual y documentar la ambigüedad.**
> Cambiarlo sin poder verificar cuál de los dos significados aplica sería
> exactamente el error que este repo intenta no repetir.

**`comper_gasto` tiene un `96` sin cubrir.** El `case_when` de
`2_recode.R:113-119` contempla `1:5`, `85`, `88` y `99`, pero 1 caso trae `96` y
cae a `NA`. Es el "NA misterioso" del comentario `#! Quedó un NA`
(`2_recode.R:231`). Fix de una línea.

**`comper_gasto` ya aplica el criterio correcto de §1:** mapea `85 → 0` ("no
gasta"), porque ahí `85` significa "no tiene medidas". Dejarlo escrito como
precedente; es el mismo razonamiento de D1.

**Dependencia silenciosa de `library()`:** `. %in% c(85, 88, 99)` sobre un vector
`haven_labelled` **falla** si `sjlabelled` no está cargado. En el pipeline
funciona porque los scripts la cargan, pero el patrón
`replace(., which(. %in% code), NA)` —que es la regla #1— depende del orden de
`library()`. Con `tar_option_set(packages = )` esto queda declarado en un solo
lugar, lo que mitiga el problema; anotarlo igual.

### Criterio de aceptación

El CSV existe, la columna de decisión no tiene celdas vacías, y cada decisión
distinta de "mantener" tiene justificación escrita.

---

## FASE 3 — Decisiones sustantivas

**Estado: ABIERTA.** D1 y D3 aplicadas; D4, D6 y D7 cerradas sin cambio de
código. Quedan **D2** y **D5**.

### Regla de ejecución

**D1 a D4 tocan `cfg$VARS_REC_TERCIL`**, o sea el input del MCA: cambian los
clusters y todo lo reportado. **D5 no** — `desordenes_ind_rec` e
`incivilidades_ind_rec` están en `cfg$VARS_SEC`, alimentan descriptivos, no el
modelo. Se puede ejecutar suelta. **D6 está cerrada y no cambia nada**: se
mantiene la convención vigente.

**D6 fija el criterio del proyecto** para la no-respuesta parcial dentro de una
batería: cuenta como no adhesión y el índice se mantiene en rango. D5 es el único
lugar donde hoy se aplica un criterio distinto, y por eso su arreglo se define
por consistencia con D6, no por preferencia metodológica nueva.

Las causas de pérdida están casi limpiamente separadas: la suma de `n_solo` es
5.622 de 6.365 eliminados, o sea que solo 743 casos tienen `NA` en más de una
variable. **D1–D4 son casi aditivas**: se pueden estimar por separado.

Con el DAG ya construido, cada decisión es un cambio en **una** función y
`tar_make()` recalcula solo lo que corresponde. El log muestra el delta.

---

### D1 — "ninguna" vale 10% / 11,1% en vez de 0%

**Recomendada. Afecta al MCA. Vive en `spec_indices` + `construir_indices_pct()`.**

`comgen_medidas_na` y `comgen_vecinos_medidas_na` siguen dentro de `source.cols`
(`2_recode.R:65` y `:76`), pasados a `create_var_pct(success.cats = 1)`. Marcar
"ninguna" cuenta como *éxito* e infla el denominador.

- 6.006 personas que dijeron "ninguna medida" reciben `comgen_per_pct = 10`
  (= 1/10), nunca 0. Solo 1 caso en toda la base tiene 0.
- 17.255 reciben `comgen_com_pct = 11,1` (= 1/9).
- Quedan **indistinguibles** de quienes tienen exactamente una medida real: de
  los 20.936 casos con `comgen_per_pct = 10`, 6.006 son "ninguna" y 14.930 son
  "una medida".

El fix de §1 los rescató del `drop_na()` pero los dejó codificados como si
tuvieran una medida.

**Acción:** sacar las columnas `_na` de `source.cols` y definir el 0% explícito.

---

### D2 — `ntile()` parte los empates por orden de fila

**Recomendada. Afecta al MCA. Es la de mayor impacto. Vive en
`categorizar_indices()`.**

`2_recode.R:169` usa `ntile(., 3)`, que fuerza grupos de igual tamaño. Con 9–11
valores distintos y empates enormes, **personas con respuestas idénticas caen en
terciles distintos**:

| Variable | Valor | T1 | T2 | T3 |
|---|---|---|---|---|
| `comgen_per_pct` | 10 | 18.563 | 2.373 | — |
| `comgen_com_pct` | 11,1 | 17.983 | 14.956 | — |
| `comgen_com_pct` | 22,2 | — | 3.028 | 7.698 |
| `emper_barrio_pct` | 0 | 18.248 | 2.049 | — |

O sea: 2.049 personas que respondieron "seguro" de día y de noche en su barrio
quedan etiquetadas *"Media inseguridad en el barrio"*.

Como `ntile()` desempata por orden de aparición, **reordenar la base cambia las
categorías**, y con ellas el input del MCA. Es un problema de reproducibilidad
además de validez.

Afecta también a `desordenes_ind_rec` e `incivilidades_ind_rec`
(`4_add_vars.R:43` y `:56`): 18.599 / 18.599 / 18.598 exactos, la firma del corte
forzado.

**El diagnóstico corregido (12-ago-2026):** no es "pocos valores distintos y
muchos empates", es **asimetría de la distribución**. Un valor que reúne más
gente de la que cabe en un tercil se parte, tenga la variable dos valores
posibles o cuarenta.

El caso extremo son los dos índices de **dos ítems** (`emper_barrio_pct`,
`emper_casa_pct`), que solo pueden valer 0, 50 o 100 — ya vienen con las tres
categorías que el modelo necesita:

| `emper_casa_pct` | Baja | Media | Alta |
|---|---|---|---|
| **0** | 18.564 | 18.563 | **5.088** |
| 50 | — | — | 8.556 |
| 100 | — | — | 4.919 |

Las 42.215 personas que respondieron sentirse seguras en su casa de día y de
noche quedan repartidas en las tres categorías, y 5.088 de ellas terminan
etiquetadas "Alta inseguridad en la casa". De esa categoría, el **27% respondió
0% de inseguridad**. Ocurre porque tres cuartos de la muestra responden 0% en
esta variable, de modo que ese único valor ocupa más de dos terciles.

Corolario para la decisión: los índices con **más** valores posibles
(`emper_ep_pct` tiene 43) están **menos** afectados, no más.

**Recomendación:** cortes sustantivos fijos definidos a priori (ej. 0 medidas /
1–2 / 3+). Interpretables, reproducibles, y compatibles con el 0% que introduce
D1. Para los dos índices de dos ítems basta con **usar el valor del índice como
categoría**: 0, 50 y 100 son las tres categorías, sin necesidad de definir
cortes. `[ABIERTO]` — ver P4.

---

### D3 — `perper_delito` categoría 5 mezcla respuesta con no-respuesta

**APLICADA (Fase 3, commit `e2144c4`) y verificada. Corrección de validez, no de
recuperación muestral. Vive en `construir_perper_delito()`.**

La categoría 5 se define en `2_recode.R:103` y su etiqueta (`labels.R:50`) es
*"No sabe/No responde de qué delito será victima **/ Cree que será victima de
otro tipo de delito**"*. Mezcla no-respuesta con respuesta sustantiva en un solo
código, y `3_add_clust.R:73` manda las categorías 4 y 5 a `NA`.

Lo importante: **las columnas originales ya vienen separadas**. La categoría 5 se
arma con `perper_p_delito_pronostico_{77, 88, 99}`, donde `77` = "Otros delitos"
(sustantivo) y `88`/`99` = no sabe / no responde. La mezcla la introduce nuestro
`case_when`, no la ENUSC.

**Acción:** partir la categoría 5 en dos — `77` como categoría sustantiva propia
que se conserva en el modelo, `88`/`99` como no-respuesta.

#### Magnitud real (verificada, corrige una estimación errónea del plan)

Los 2.539 `NA` de `perper_delito` se reparten así:

| Origen | Casos |
|---|---|
| Categoría 4 — `P_EXPOS_DELITO` en `88`/`99` | **2.389** |
| Categoría 5 — total | **150** |
| — de esos, con `__77` marcado (sustantivo, lo que D3 rescata) | **78** |

**D3 recupera 78 casos, no 2.182.** El N pasó de 49.431 a **49.503** (+72: los 78
menos 6 que otra variable también descartaba), y `n_na` de `perper_delito` bajó de
2.539 a 2.461. Eso es exactamente lo correcto.

> **Corrección.** Una versión anterior de este plan predecía **51.613** casos
> tras aplicar D3, asumiendo que los 2.182 de `n_solo` provenían todos de la
> categoría 5 vía `77`. Es falso: la abrumadora mayoría (2.389) es categoría 4,
> no-respuesta pura en la pregunta filtro, que D3 no toca ni debe tocar. La
> predicción estaba mal, no la implementación. **No usar 51.613 como criterio de
> verificación.**

El valor de D3 es conceptual —deja de tratar una respuesta sustantiva como
ausencia de dato— y no debe evaluarse por cuántos casos recupera.

---

### D4 — Ítems excluidos por rango posicional

**CERRADA (12 de agosto de 2026) para `P_INSEG_LUGARES`. Vive en
`spec_indices`.**

**Resolución del usuario:** el criterio se definió en discusión con el equipo —
el índice de espacio público incluye **todas las situaciones clasificables como
espacio público**, entendido como espacio de circulación y uso general. Los cinco
ítems excluidos no lo son: dos están referidos al barrio de la persona (que es
otra dimensión del análisis) y tres son espacios de uso propio o acceso
restringido (su trabajo, su estudio, el banco). El código ya implementaba esta
decisión; lo que faltaba era que estuviera escrita.

Documentada en la página, F5.4, sección "Qué situaciones entran en cada índice",
con la tabla de los 16 ítems marcando cuáles entran. La tabla se deriva de
`spec_indices`, así que sigue siendo correcta si el spec cambia.

**Queda abierto el caso de `P_MOD_ACTIVIDADES`:** el ítem 14 ("Hacer otra
actividad") sigue excluido sin criterio escrito. Es de bajo impacto —es un
catch-all, no una actividad concreta— pero corresponde resolverlo con el mismo
estándar.

Los índices se construyen con rangos posicionales que truncan las baterías sin
que nada falle:

| Batería | Ítems en el instrumento | Usados | Excluidos |
|---|---|---|---|
| `P_INSEG_LUGARES` | **16** | `1:11` (`2_recode.R:43`) | 12 plazas/parques del barrio · 13 comercios del barrio · 14 lugar de trabajo · 15 lugar de estudio · 16 el banco |
| `P_MOD_ACTIVIDADES` | **14** | `1:13` (`2_recode.R:53`) | 14 "Hacer otra actividad" |

Y `helpers/dic_items.R` documenta **solo los ítems incluidos**, así que el
diccionario —que existe para detectar deriva de cuestionario— **bendice la
truncación en vez de delatarla**.

Es la misma decisión abierta del repo viejo ("el ítem 16, En el banco"), pero son
cinco ítems, no uno.

La lectura que este plan había anotado como hipótesis —que los ítems 12 y 13
pertenecen a la dimensión barrio— resultó ser parte del criterio real, pero no
todo: el criterio del equipo es positivo (qué **es** espacio público), no una
lista de exclusiones caso a caso.

**Independientemente de lo que se decida:** el diccionario debe registrar los 16
ítems y marcar cuáles se excluyen y por qué.

---

### D5 — `88`/`99` se comportan como "nunca ocurre"

**`[ABIERTO]` — pendiente de P5 (cómo aplicar el criterio, no cuál). NO afecta al
MCA. Vive en `construir_indices_secundarios()`.**

`4_add_vars.R:42` y `:55` mandan `88`/`99` a `NA` y suman con
`rowSums(..., na.rm = TRUE)`. El ítem desaparece del sumatorio en vez de
invalidar el caso, así que **"no sabe" se comporta como "el desorden nunca
ocurrió"**.

| | ≥1 ítem en 88/99 | todos los ítems en 88/99 |
|---|---|---|
| desórdenes (8 ítems) | **6.563** (11,8%) | **17** → índice 0 |
| incivilidades (7 ítems) | **1.839** (3,3%) | **20** → índice 0 |

El mínimo real con todos los ítems válidos es 8 (rango verificado: 8–40). Los 17
que respondieron `88`/`99` a las ocho preguntas quedan en índice **0**, por
debajo del mínimo posible, y caen en el tercil 1 etiquetado *"Baja percepción de
desordenes"*. Los 6.563 con respuesta parcial quedan deflactados en proporción a
cuántas preguntas esquivaron.

Mismo patrón de §1 en otro lugar, y acá además sesga sistemáticamente hacia el
polo bajo.

**Lo que lo distingue de D6, y por qué no es la misma decisión.** D6 es una
convención deliberada donde la no-respuesta cuenta como no adhesión y **el índice
se mantiene dentro de su rango teórico**. D5 no cumple eso: produce valores
**fuera de escala**. Con 8 ítems de `1` a `5`, el mínimo posible es 8; los 17
casos con todos los ítems en `88`/`99` quedan en **0**, un valor que ninguna
combinación de respuestas válidas puede producir.

Es decir: `na.rm = TRUE` no aplica la convención de D6 mal — aplica **otra
convención distinta**, y una que rompe la escala.

**Acción recomendada:** hacer D5 consistente con D6. Dos formas, en orden de
preferencia:

1. **Construir el índice con `create_var_pct()`**, igual que los demás. Queda
   estructuralmente idéntico al resto, la convención se hereda sola y deja de ser
   un caso especial que alguien tiene que recordar.
2. Si se prefiere conservar la suma: asignar el valor mínimo de la escala (`1`,
   "nunca") a los ítems no respondidos, de modo que el mínimo del índice sea 8 y
   no 0.

Lo que **no** corresponde, dado el criterio ya fijado en D6, es prorratear: sería
introducir una tercera convención en el mismo proyecto.

---

### D6 — `88`/`99` quedan en el denominador de los índices `_pct`

**CERRADA: es una convención deliberada, se mantiene. Se documenta y se reporta.**

No es un hallazgo ni un bug: el usuario confirmó que fue una decisión consciente.
Queda aquí registrada porque hasta ahora no estaba escrita en ninguna parte, y
porque **fija el criterio del proyecto** para la no-respuesta parcial dentro de
una batería — criterio que D5 hoy no respeta (ver más abajo).

En `create_var_pct()` (`functions.R:495-498`):

```r
not_valid = sum(if_else(value == 85, 1, 0)),   # solo 85 sale del denominador
n_valid   = n() - not_valid,
n_success = sum(if_else(value %in% success.cats, 1, 0))
```

`85` se excluye del denominador, pero **`88` y `99` se quedan** — y nunca pueden
ser éxito. Responder "no sabe" a un ítem cuenta exactamente igual que haber
respondido "me siento seguro".

| Índice | Ítems | Casos con ≥1 ítem en `88`/`99` |
|---|---|---|
| `emper_ep_pct` | 11 | **1.573** (2,8%) |
| `comper_pct` | 13 | **752** (1,3%) |
| `emper_barrio_pct` | 2 | 163 (0,3%) |
| `emper_casa_pct` | 2 | 33 (0,1%) |

Es la misma clase de error que D5 —no-respuesta convertida en respuesta
sustantiva— pero **en variables que entran al MCA**, no en las secundarias. Y es
asimétrico: siempre empuja el porcentaje hacia abajo, o sea hacia "menos miedo".

Los casos con **todos** los ítems en `88`/`99` sí están cubiertos por
`recuperar_codigos_especiales()`. Los afectados son los de no-respuesta
**parcial**.

**La convención que esto establece:** un ítem no respondido cuenta como no
adhesión — se comporta como un "no" en la escala. Es defendible y, sobre todo,
mantiene el índice **dentro de su rango teórico**: un `_pct` sigue estando entre
0 y 100 pase lo que pase.

**Acción en el refactor:** ninguna sobre el cálculo. Lo que sí se hace es
**reportarlo**: `reportar_transformacion()` debe exponer, para cada índice `_pct`,
cuántos casos aportaron ítems en `88`/`99` al denominador. Hoy ese número no es
visible en ninguna parte, y la convención se aplica sin que se vea su magnitud.

El razonamiento de la decisión va escrito en el inventario de la Fase 2 (§F2),
con esta entrada como precedente: es el criterio del proyecto para la
no-respuesta parcial.

---

### D7 — La categoría 4 de `perper_delito` se descarta sin que nadie lo decidiera

**RESUELTA (11 de agosto de 2026): se mantiene fuera del modelo (opción 1), sin
cambio de código.** Vive en `preparar_datos_mca()`.

Apareció al verificar D3. Con D3 ya aplicada, **la categoría 4 es de lejos la
mayor fuente individual de pérdida del modelo: 2.389 casos**, más que el resto de
las variables juntas.

Son las personas que respondieron `88` o `99` a `P_EXPOS_DELITO`, la pregunta
filtro ("¿cree usted que será víctima de algún delito en los próximos doce
meses?"). `preparar_datos_mca()` las manda a `NA` junto con la categoría 5, y esa
línea se heredó del código viejo (`3_add_clust.R:73`) sin discusión.

Descartarlas es **defendible**: es no-respuesta genuina en la pregunta que abre la
dimensión, y a diferencia del caso de §1 no hay ninguna respuesta sustantiva
escondida ahí — es tipo B, el `88`/`99` es un valor de la columna y significa
exactamente lo que dice.

Pero nunca fue una decisión, fue una herencia. Y es la única fuente de pérdida de
esta magnitud que no pasó por el criterio de §1.

**Acción mínima:** entre al inventario de la Fase 2 como decisión escrita, con su
justificación, aunque la resolución sea "se mantiene". Si se decide conservarlas,
hay que definir qué categoría se les asigna en el MCA, y eso sí es sustantivo.

#### Composición del grupo excluido (verificada, corrida específicamente para D7)

`reportar_composicion()` sobre los 2.389 casos de categoría 4 contra el resto de
la muestra (`output/tables/2025/composicion_d7_categoria4.csv`). El sesgo es real
y va en la misma dirección que el hallazgo de §1:

| Variable | Categoría 4 | Resto | Diferencia |
|---|---|---|---|
| `rph_nse` = bajo | 57,6% | 45,9% | +11,7 pp |
| `rph_nse` = alto | 8,0% | 15,8% | −7,8 pp |
| `rph_edad_rec` = 60+ | 49,7% | 30,1% | +19,6 pp |
| `rph_nivel_rec` = básica o menos | 27,4% | 16,5% | +10,9 pp |
| `rph_nivel_rec` = terciaria | 25,4% | 40,7% | −15,3 pp |
| `vp_dc` (victimización hogar) = 1 | 16,2% | 24,1% | −7,9 pp |

Gente mayor, de NSE y educación más bajos, y con menos victimización previa del
hogar, está sobrerrepresentada entre quienes no responden la pregunta filtro. No
es aleatorio.

**Decisión (11 de agosto de 2026, con el usuario): opción 1, se mantienen fuera
del modelo. Sin cambio de código** — `preparar_datos_mca()` ya hace exactamente
esto. La composición sesgada queda documentada como una limitación conocida del
modelo, no como algo a corregir en esta fase.

### Criterio de aceptación de la Fase 3

Las siete decisiones (D1–D7) tienen resolución escrita: adoptada o descartada, con
motivo. D1 y D3 ya están aplicadas y verificadas; D6 y D7 cerradas sin cambio de
código (D7 con composición verificada). Quedan D2, D4 y D5.
`reportar_composicion()` corrido para cada decisión adoptada, y el log mostrando
el delta de cada una.

**Al verificar una decisión, descomponer primero el `NA` por su origen** antes de
predecir cuántos casos recupera. Ver la corrección en D3 y la nota sobre `n_solo`
en §F1.5.

---

## FASE 4 — Medición de variantes

**Estado: ABIERTA.**

Con el DAG construido, comparar variantes es ramificar sobre el parámetro de
`categorizar_indices()` o sobre `spec_indices`, no copiar un script. Comparar N
que entra, tamaños de cluster y perfil (`v-test`).

Dos trampas conocidas:

**El % de inercia no es comparable entre variantes con distinto número de
categorías** por variable (más categorías → más inercia total, mecánicamente).
D2 cambia justamente eso. O se implementa la corrección de Benzécri
(`GDAtools::modif.rate()`, aplica sobre el objeto `acm` sin re-correr nada; hoy
`GDAtools` no está instalado), o se decide explícitamente **no comparar
inercias**. Lo segundo es defendible; comparar sin corregir, no.

**Costo de memoria.** El contrafactual del repo viejo saturó la máquina de
desarrollo (RSS ~14 GB, swap al 96%) con `N ≈ 49.400` y cinco soluciones. Acá son
tres, debería pasar, pero correr **una variante a la vez**. Con el MCA y el HCPC
separados en targets distintos (§F1.4), el MCA ya no se recalcula por solución, lo
que ayuda.

---

## FASE 5 — Gold, testbed y `analysis/`

**Estado: ABIERTA. No empezar antes de cerrar la Fase 3.**

Un gold no sirve para saber si un número está *bien* — para eso no hay contra qué
comparar cuando se parte de cero. Sirve para detectar **cambios no
intencionales**. Sin decisiones cerradas no hay nada que congelar.

### F5.1 Gold y testbed

Anclar sobre los CSV de log, que para entonces llevan varias corridas de
historia. Calibrar `max_perdida` en `reportar_perdida()` con el valor real de la
corrida final más un margen: ahí los reportes dejan de informar y pasan a ser
aserciones.

### F5.2 Reparar `analysis/`

Hoy ninguno de los dos scripts corre. Repararlos **después** de la Fase 3: sus
vectores de variables dependen de D1–D4, así que arreglarlos antes es hacerlo dos
veces. Además, con el almacén de targets, los `readRDS(cfg$FILE_...)` pasan a ser
`tar_read()`.

| Archivo | Problema |
|---|---|
| `descriptivos.R:34`, `descriptivos_iniciales.R:33` | `source("tipologias/config.R")` — ruta del repo viejo |
| `descriptivos.R:43` | Typo `stata = ` en `as_survey_design()`. Se lo traga en silencio y el diseño queda **sin estratificar** |
| `descriptivos.R` | Usa `cfg$VARS_REC` y `cfg$VARS_REC2`; solo existe `VARS_REC_TERCIL` |
| `descriptivos.R:36` | `cfg$PATH_HELPERS_AN` apunta a `analysis/helpers/` — **no existe en este repo**; sí en el viejo |
| `descriptivos.R` | Llama `tab_var_clust()`, ausente en este repo. **Existe en el viejo**: `tipologias/analysis/helpers/functions.R` |
| `descriptivos.R:48` | Lee `cfg$FILE_METADATA`, que ningún script escribe |
| `descriptivos_iniciales.R` | Carga en `enusc_original` pero opera sobre `enusc`; llama `esperado("patrones")`, ausente acá. **Existe en el viejo**: `tipologias/processing/helpers/validate.R` |

> **Aviso de redacción.** Las frases "no existe" de esta tabla se refieren
> **siempre a este repo**. Antes de concluir que algo hay que escribir de cero,
> buscar en `/Users/mar/Work/Github/2025_pnud_miedo` **completo** — incluyendo
> `tipologias/analysis/helpers/`, que no es donde apuntan las rutas de este plan.

#### Decisiones resueltas (11 de agosto de 2026)

Resueltas con el usuario tras el reporte de estado de `analysis/`. Ejecutar como
están; ninguna queda abierta.

| # | Decisión |
|---|---|
| **Q1** | **Portar los 5 helpers tal cual**, sin arreglarlos. `tab_frq1()` tiene advertencias conocidas en su docstring (el `separate()` que trunca "Robo en su vivienda" → "Robo "); se corrigen **después**, como paso separado y con el log mostrando el delta. Arreglar mientras se porta hace el port inverificable |
| **Q2** | **Portar `tab_var_clust()` desde el repo viejo**, no escribirla. Al portarla aplicar §F1.6: tiene `path = cfg$PATH_TABLES` como argumento por defecto que lee un global (hacerlo explícito), y escribe Excel como efecto secundario con `save = TRUE`, lo que choca con la regla #7 |
| **Q3** | **Extraer solo `patrones`** como target `spec_patrones`. **No** portar `validate.R` (708 líneas): `esperado()` es el accesor de `ESPERADO`, que es maquinaria de gold y corresponde a F5.1. Valores reales abajo |
| **Q4** | **Sacar `pergen_pais`, `pergen_comuna` y `pergen_barrio` de `VARS_SEC`** en `R/config.R`. La dimensión pergen se descartó a propósito y no se necesita. No cambia ningún número (`reportar_composicion()` ya las saltaba). **Agregar además una aserción** de que todo nombre de `VARS_SEC` exista en los datos finales — cierra la clase entera de bug, aplicando el patrón declarado-vs-observado de §4.1.5 a `cfg` |
| **Q5** | **Descartar la hoja de metadata** de `descriptivos.R`. No resucitar `gen_metadata_recode.R`. Su propósito —documentar qué variables originales construyen cada índice— ya lo cumplen `spec_indices` y `spec_variables`, mejor estructurados; si la hoja se quiere de vuelta, se deriva de ahí |

Valores de `spec_patrones` para 2025, tomados del repo viejo (no inferidos):

```r
list(
    emper  = list(sep = "\\? "),
    perper = list(sep = "(\\?|en su|en el)\\s*"),
    pergen = list(sep = "(\\?|en su|en el)\\s*"),
    comper = list(extraer = '"([^"]+)"'),
    comgen = list(sep = "(\\?|\\.)\\s*")
)
```

#### Deuda de Fase 1 que hay que cerrar acá

**§F1.4 listaba seis helpers a preservar y solo se portó uno** (`create_var_pct()`,
porque el pipeline principal lo usa). Faltan `tab_frq1()`, `tab_frq2()`,
`format_tab_excel()`, `pre_proc_excel()` y `plot_mca()`.

No es trabajo de Fase 5: es Fase 1 incompleta, que no se notó porque ningún target
los consumía. **Se cierran con el criterio de la Fase 1, no con el de la Fase 5**:
fidelidad al original, sin mejoras.

### F5.3 Tablas descriptivas en el pipeline

**CONSTRUIDA (12 de agosto de 2026).** Targets nuevos en `R/descriptivos.R` +
`_targets.R`, no script en `analysis/`. Las 6 tablas + `diseno_muestral` +
`mapeo_nombres`, con salida Excel + CSV en `output/tables/2025/`. Todas
estampadas "provisional" salvo la tabla 1 (variables originales, no depende de
ninguna decisión abierta) — cada una con el motivo específico (D2 y/o D5)
en vez de un sello genérico.

#### Por qué no espera a D2/D4

`F5.2` manda esperar a D2/D4 para reparar `descriptivos.R`, porque ese script
referencia `cfg$VARS_REC2`, que depende de cómo quede la categorización. Eso
aplica a **reparar el script viejo**, no a construir targets nuevos sobre lo que
ya existe.

Y hay un argumento activo a favor de construirlas ya: **si son targets, adoptar
D2 las regenera solas**, y se podrá ver su efecto sobre cada tabla descriptiva y
no solo sobre los tamaños de cluster. Eso es exactamente el rendimiento por el
que se adoptó `targets`.

**Los outputs quedan provisionales hasta cerrar D2.** Estamparlo en el propio
archivo generado, no solo acá.

#### Qué tablas

| # | Tabla | Contenido |
|---|---|---|
| 1 | **Variables originales** | Univariados de todas las columnas crudas, por dimensión (`emper`, `perper`, `comper`, `comgen`). Usa `spec_patrones` para separar enunciado de ítem |
| 2 | **Variables fuente** | Univariados de los índices `_pct` continuos **y** de sus versiones categorizadas, más `perper_delito` y `comper_gasto` |
| 3 | **Variables secundarias** | Univariados de `cfg$VARS_SEC` |
| 4 | **Variables de clusters** | Distribución de `clusters_4`, `clusters_5`, `clusters_6` |
| 5 | **Cruces × cluster** | Variables fuente × cluster y variables secundarias × cluster, con `cfg$CLUSTER_A_SACAR`. Dirección **`invert = FALSE`**: distribución de la variable *dentro de cada cluster*, que es el perfil pedido. La dirección invertida contesta otra pregunta y no se pide |
| 6 | **`v-test`** | Perfil estadístico de cada cluster |

**Plantilla para la tabla 1:** el reporte del repo viejo,
`web/reportes_originales/tab_desc_initial_2025.html`. Está organizado por
dimensión, con el enunciado de la pregunta como encabezado y columnas
`categoria · val · label · frq · prc · cum.prc`. Replicar esa estructura. Ojo:
tenía una sección "Perceptual - General" (`pergen`) que **ya no corresponde** —
esa dimensión se descartó.

**La tabla 1 debe acompañarse del mapeo original → nuestro nombre** (§4.0), para
que se pueda ir de `P_INSEG_LUGARES_1` a `emper_p_inseg_lugares_1` sin leer
código.

#### `v-test` (tabla 6)

`HCPC` ya lo calcula: está en `clust$desc.var` dentro del target `hcpc`, y hoy no
se expone. Ordena las variables por cuánto distinguen a cada grupo, en vez de
dejar comparar veinte tablas a ojo, así que es probablemente lo más útil para
**caracterizar y nombrar** los clusters. Sacarlo es barato: es un target que lee
algo ya computado.

#### Regla: log ≠ tablas descriptivas

`output/logs/marginales.csv` ya tiene la distribución de 42 variables en 13
etapas. Tiene la misma forma que estas tablas y **no es lo mismo**:

| | Log (`marginales.csv`) | Tablas descriptivas |
|---|---|---|
| Ponderación | **Sin ponderar** | **Ponderadas** (`fact_pers_reg`) |
| Propósito | Diagnóstico: detectar que algo cambió | Reporte: estimar la población |
| Audiencia | Quien desarrolla | PNUD |

**Nunca se citan números del log en un entregable.** Sin esta regla escrita, en
unos meses va a haber dos tablas de frecuencia de la misma variable con números
distintos y nadie va a saber cuál reportar.

#### Trampa: el objeto de diseño muestral

Las tablas ponderadas necesitan un diseño muestral y **hoy no existe ninguno en
el DAG**: `cfg$SVY_IDS`, `SVY_STRATA` y `SVY_WEIGHTS` están definidos y no los
usa nadie. Hay que crear ese target.

Es exactamente donde vivía el typo `stata = ` del repo viejo, que
`as_survey_design()` se tragaba en silencio dejando el diseño **sin
estratificar** (`descriptivos.R:43`). El target debe llevar una aserción de que
los tres nombres existen en los datos, al estilo de `validar_vars_sec()`.

#### Formato de salida

- Targets `format = "file"`, para que el DAG los rastree. Si se escriben como
  efecto secundario quedan fuera del grafo y se viola la regla #7.
- Excel para el entregable, vía `format_tab_excel()`, en `output/tables/2025/`.
- **CSV al lado de cada Excel**, por coherencia con `F0.3`: el registro
  versionado es texto, y un Excel no es diffeable.
- Antes de bifurcar en Excel y CSV, pasar por `limpiar_tabla_descriptiva()`
  (descarta filas de categoría vacía **solo si `frq == 0`**, y redondea). Así
  ambas salidas tienen las mismas filas y columnas.

> **No usar `pre_proc_excel()` acá.** Una versión anterior de esta sección lo
> pedía. Esa función convierte los números a **texto** en formato español, y su
> docstring dice para qué: comparar Excel contra un gold como strings exactos.
> Es una necesidad del testbed (F5.1), no del entregable. Aplicarla deja un
> Excel donde no se puede ordenar ni calcular, y un CSV con comas decimales que
> el testbed tendría que reparsear — siendo que el CSV **es** el registro
> versionado. Si el gold llega a necesitar formato texto, se aplica en F5.1
> sobre el Excel, sin tocar el camino del CSV.

#### Ordenamiento del `v-test`

**No ordenar por `v.test`.** `FactoMineR` lo deriva invirtiendo el p-value, y
con N≈49.500 el p subdesborda a 0, de modo que `qnorm(0)` da `Inf`. En la
primera corrida **61 de 118 filas quedaron en `Inf`** y el orden se perdía justo
entre las asociaciones más fuertes, que son las que sirven para nombrar el
cluster.

Ordenar por `lift_pp = Mod/Cla - Global`: puntos porcentuales de sobre o
sub-representación de la categoría dentro del cluster. Siempre finita,
interpretable, y con el mismo signo que `v.test`. Conservar `v.test` y `p.value`
como columnas de referencia, con sus `Inf` intactos — son el valor real que
devuelve `HCPC`, no un error que tapar.

---

### F5.4 Página de resultados

**RESUELTA (11 de agosto de 2026).** Cambia el alcance: el sitio Quarto estaba
declarado fuera de alcance en versiones anteriores de este plan. Entra ahora
porque el propósito cambió.

#### Propósito

La página anterior comunicaba **resultados**. Esta comunica **resultados y las
decisiones que los producen** — es el motivo por el que se hizo todo el refactor.
Dos objetivos, en este orden:

1. Explicitar las decisiones metodológicas tomadas.
2. Declarar las que siguen faltando.

**Audiencia:** el equipo de la consultoría. Gente con formación metodológica pero
no técnica en R. Lo que importa es que quede claro **qué se hace y cómo afecta al
análisis**, no cómo está implementado.

#### Diseño

Igual a la anterior (`theme: cosmo`, sin SCSS propio), con **un solo cambio**:
el azul pasa a negro, para distinguirlas de un vistazo. Es un `custom.scss` que
sobreescribe `$primary` sobre cosmo; no se toca nada más.

Tablas con **`kableExtra` + tabsets**. **No** usar tablas interactivas: las de la
página anterior no fueron bien recibidas.

#### Pestañas

**1. Introducción.** De dónde venimos: la consultoría parte en 2024, se rehace en
2025, y un hallazgo obliga a rehacer los análisis (§1). Más una sección corta de
cómo leer la página, porque el cambio de propósito respecto de la anterior no es
evidente.

**2. Pipeline.** El corazón. Recorre las etapas del DAG deteniéndose en las que
procesan los datos de forma que afecte el análisis. En cada una, un cuadro
(callout) con la decisión metodológica correspondiente.

| Etapa | Qué se explica | Decisión |
|---|---|---|
| Selección | Kish, qué dimensiones entran | Por qué se descartó `pergen` |
| Códigos especiales | La tipología A/B/C de §4.1: dónde vive el `85`/`88`/`99` | El hallazgo de §1, con "ninguna" como ejemplo |
| Construcción de índices | Ejemplo trabajado, con la aritmética a la vista | D1, D6 |
| Categorización | Cómo se pasa de % a categorías | **D2, abierta** |
| Preparación del modelo | Quiénes salen y por qué | D3, D5, D7 y el sesgo del excluido |
| MCA + HCPC | Qué hace cada uno, en términos no técnicos | — |

**Ser pedagógico es requisito, no adorno.** Para los índices, usar un ejemplo
trabajado con `emper_ep_pct`: una persona, once lugares, mostrando que los `85`
("no aplica" — p. ej. no hay Metro en su ciudad) **salen del denominador**
mientras que los `88`/`99` **se quedan** (D6). La aritmética explícita vuelve
concreta en dos líneas una convención que en prosa cuesta un párrafo.

Para "qué casos salen" no hay que calcular nada: `perdida_detalle.csv` ya tiene
`n_na`/`n_solo` por variable y `composicion_mca.csv` el perfil de los excluidos.

Cierra con un **registro de decisiones**: tabla D1–D7 con estado, qué cambió y
qué falta. Los cuadros inline apuntan ahí. Si crece, es candidato a pestaña
propia.

**3. Univariados.** Tablas 1, 2 y 3 en tabsets: las originales agrupadas por
dimensión (`emper`, `perper`, `comper`, `comgen`), el resto por familia según
§4.0. Acompañar las originales con `mapeo_nombres`, para poder ir de
`P_INSEG_LUGARES_1` a `emper_p_inseg_lugares_1` sin leer código.

**4. Solución actual.** Ajuste global y mapa de categorías (comunes a las tres
soluciones: el MCA es el mismo, lo que cambia es dónde se corta el árbol), y
luego **una subpestaña por solución** (4, 5 y 6 grupos) con mapa de clusters,
tamaños, `v-test` y perfil.

Los cruces van en **formato ancho**: una fila por categoría, una columna por
cluster, con el % de esa categoría dentro de cada cluster (`tabla_cruces_ancho`).
Es el formato con el que el equipo lee los perfiles.

**Los gráficos no son los de `factoextra`.** Los de la librería sirven para
explorar, no para comunicar: no distinguen dimensión teórica, superponen
etiquetas y dibujan 49.503 puntos individuales donde solo se necesita leer dónde
está el núcleo de cada grupo. Se replica el sistema de la página anterior:
biplot de categorías coloreado por dimensión con `ggrepel`, y mapa de clusters
con centroide y contorno al 50%.

**El corte entre cálculo y dibujo:** las funciones de `R/graficos.R` preparan
datos (coordenadas, centroides, la matriz de covarianza de cada elipse) y son
targets; el `.qmd` dibuja. Así el cálculo queda trazable y el estilo se puede
ajustar sin invalidar el DAG.

Dos advertencias que van en esta pestaña, no solo en el plan:

- Todo es **provisional hasta D2**.
- El **% de inercia no es comparable** entre variantes con distinto número de
  categorías — que es justamente lo que D2 cambia.

#### Regla de datos: el `.qmd` no calcula

**Todo número que aparezca en la página nace en un target.** El `.qmd` solo lee
(`tar_read()`), pivotea y formatea. Dos razones: ningún número del entregable
nace en un chunk sin trazabilidad, y la página se regenera sola cuando D2
aterrice.

Insumos ya disponibles en el DAG:

| Target | Para |
|---|---|
| `tabla1_variables_originales`, `tabla2_variables_fuente`, `tabla3_variables_secundarias` | Univariados |
| `mapeo_nombres` | Univariados (originales) |
| `tabla4_clusters` | Solución actual |
| `tabla_cruces_ancho_clusters` | Cruces de la solución reportada, formato ancho |
| `cruces_ancho_todas` | Cruces de las tres soluciones |
| `tabla6_v_test`, `v_test_todas` | `v-test`, ordenado por `lift_pp` |
| `tabla_ajuste` | Ajuste global (inercia) |
| `datos_biplot_mca` | Coordenadas de categorías para el biplot |
| `mapa_clusters` | Centroides y elipses de las tres soluciones |
| `output/logs/perdida_detalle.csv`, `composicion_mca.csv`, `transiciones.csv` | Pipeline: pérdida, sesgo, flujos |

#### Estado de los clusters

Salen como `C1`–`C5`, sin nombres sustantivos. **Nombrarlos es una decisión del
equipo que sigue pendiente**, heredada del repo viejo, y esta página es
precisamente el insumo para tomarla: la tabla de cruces en formato ancho más el
`v-test` son las dos piezas que permiten caracterizar cada grupo.

#### Pendiente de mecánica

- `kableExtra` no está instalado. Agregar a `renv` y a `tar_option_set()`.
- El `.qmd` necesita apuntar al almacén de targets: Quarto renderiza desde el
  directorio del `.qmd`, así que hay que fijar el `store` explícitamente.
- Las rutas de `output/tables/2025` siguen hardcodeadas (defecto C, diferido).
  La página no debería agregar rutas literales nuevas.

---

### Fuera de alcance

Estructura de carpetas por ola más allá de la existente.

*(El sitio Quarto estaba acá y salió: ver F5.4.)*

---

## Estado de ejecución (12 de agosto de 2026)

Rama `refactor/targets`. Fases 0 a 3 ejecutadas; Fase 3 **parcial**. F5.3 construida.

| Fase | Estado |
|---|---|
| 0 — Preparación | Hecha (`b4eb745`); `renv` sincronizado (`4b64cb6`) |
| 1 — Refactor a targets | Hecha (`bcec3a5`); **deuda cerrada** en `406a27b` (5 helpers, `tab_var_clust()`, `spec_patrones`, `VARS_SEC`) |
| 2 — Inventario | Hecha (`639877a`) |
| 3 — Decisiones | **Parcial**: D1 y D3 aplicadas y verificadas (`e2144c4`). D6 y D7 cerradas sin cambio de código (D7 en `0184c33`). D4 cerrada y documentada (12-ago-2026), sin cambio de código. **D2 y D5 pendientes** |
| 4 — Variantes | No iniciada |
| 5 — Gold, testbed, `analysis/` | **F5.3 construida** (6 tablas + diseño muestral + mapeo de nombres). **F5.4 especificada, insumos del DAG listos, página sin construir.** F5.1 y F5.2 no iniciadas |

### F5.3 — hallazgo al construirla

**`cfg$SVY_STRATA` estaba mal, además del typo `stata`/`strata` ya conocido.**
Valía `"varstrat"`; la columna real (post `clean_names()` sobre `VarStrat`) es
`"var_strat"`, con guión bajo. Nunca se había ejercido porque el objeto de
diseño muestral no existía en el DAG hasta ahora. Corregido en `R/config.R` al
construir `construir_diseno_muestral()`. La aserción de columnas que pedía
F5.3 lo habría atrapado igual, pero el valor ya estaba mal, no solo el nombre
del parámetro.

### Próximo paso

**Construir la página (F5.4).** Está especificada y todos sus insumos ya son
targets. No depende de ninguna decisión abierta: sale con `C1`–`C5` y con las
tablas marcadas como provisionales.

Después: cerrar D2/D4/D5 (bloquea F5.2), y F5.1 (gold/testbed).

### Antes de continuar

1. **No empezar F5.2** (reparar `analysis/`) todavía: depende de D2 y D4, que
   siguen abiertas. F5.3 sí puede avanzar — ver su propia sección.

2. **Cerrar las decisiones abiertas.** Quedan dos: **D2** (P4) y **D5** (P5). D2
   es la más consecuente: mayor impacto del proyecto y además bloquea F5.2.

3. **Verificación retroactiva de la Fase 1.** El criterio 8 (inventario de
   traducción) se agregó *después* de ejecutada la Fase 1, y los criterios 2–4
   solo se pueden evaluar contra `54006c5` en el estado `bcec3a5`, antes de que
   D1 y D3 cambiaran los números a propósito. Si se quiere cerrar formalmente la
   Fase 1, hacerlo sobre ese commit.

4. **`renv` con `snapshot.type: "all"`.** El lockfile pasó a tener 286 paquetes,
   incluidos los que no usa el proyecto. La causa real del desajuste era que el
   escáner de dependencias de `renv` no ve los paquetes declarados en
   `tar_option_set(packages = )`. El arreglo más liviano es un `_dependencies.R`
   que los liste, volviendo a `implicit`. Funciona como está; anotado para
   cuando moleste.

5. **Residuo:** `spec_patrones` (`R/tablas.R`) todavía declara `pergen`, que ya
   no existe en ningún punto del pipeline. Inofensivo, inconsistente con Q4.

### Gran pendiente — representatividad del conjunto excluido

**Para cuando el pipeline esté funcional. No bloquea nada ahora.**

Este repo existe porque el modelo anterior excluía un subconjunto sesgado de la
muestra. D1 y D3 corrigieron parte, pero **el conjunto excluido sigue sesgado en
la misma dirección**, ahora principalmente por D7:

| `rph_nse` | Excluidos (6.293) | Incluidos (49.503) |
|---|---|---|
| Bajo | 52,4% | 45,7% |
| Alto | 12,1% | 15,9% |

Dos tareas cuando corresponda:

1. **Ampliar `reportar_composicion()` a `cfg$VARS_SEC` completo.** Hoy
   `output/logs/composicion_mca.csv` cubre solo cuatro variables (`rph_sexo`,
   `rph_nse`, `vp_dc`, `vp_dv`). Faltan edad y educación, que en la porción de D7
   mostraron las diferencias más grandes (+19,6 pp en 60 y más, +10,9 pp en
   educación básica o menos).
2. **Llevar la limitación al entregable.** El sesgo residual es menor que el
   original pero va en la misma dirección, y es exactamente el hallazgo que
   originó el reinicio. Tiene que aparecer como limitación conocida del modelo en
   lo que reciba PNUD, no solo como nota en este plan.

---

## Preguntas abiertas

Ninguna se resuelve por cuenta propia.

**P1 — ¿Entra la ola 2024?** La regla #6 dice verificar los códigos en todas las
olas disponibles, y hoy solo hay 2025. Si el entregable compara olas, D1–D4
deberían validarse en ambas antes de anclar el gold. También reabre `ANIO` como
variable de entorno.

**P2 — RESUELTA (12-ago-2026).** D4 cerrada para `P_INSEG_LUGARES`: el criterio
lo definió el equipo y está documentado en la página. Queda el ítem 14 de
`P_MOD_ACTIVIDADES` ("Hacer otra actividad"), de bajo impacto, sin criterio
escrito.

**P3 — Confirmar §F0.3**, qué se versiona tras la mudanza al almacén de targets.

**P4 — D2: ¿cortes sustantivos o volver a la dicotómica?** El repo viejo tenía la
dicotómica como solución principal y los terciles como chequeo de robustez. Si la
dicotómica ya estaba aprobada, quizás la pregunta no es cómo arreglar los
terciles sino por qué son la variante principal acá.

---

**P5 — D5: ¿`create_var_pct()` o mínimo de escala?** D6 ya fijó el criterio del
proyecto, así que la pregunta no es cuál convención adoptar sino cómo aplicarla.
La opción 1 (reconstruir el índice con `create_var_pct()`) lo vuelve
estructuralmente idéntico al resto y hace que la convención se herede sola; la
opción 2 (asignar el mínimo de escala) conserva el índice como suma. Cambia la
métrica de `desordenes_ind`/`incivilidades_ind`, así que corresponde decidirlo,
no asumirlo.

---

## Anexo A — Números verificados

ENUSC 2025, `N = 55.796` tras `filter(Kish == 1)`. Medidos el 11 de agosto de
2026 sobre los artefactos del commit `54006c5`.

### A.1 Muestra que entra al MCA

- Entran 55.796 · quedan **49.431** · eliminados 6.365 (**11,4%**)
- Coincide exactamente con el contrafactual "85 conservado como respuesta válida"
  del repo viejo (`CONTEXTO.md §4.9`)
- Clusters: 49.431 asignados, 6.365 `NA`. Verificado caso a caso contra
  `results_all` para las tres soluciones. `rph_id` sin duplicados

### A.2 Pérdida por variable

| variable | n_na | n_solo |
|---|---|---|
| `perper_delito` | 2.539 | 2.182 |
| `comgen_com_pct_rec_tercil` | 1.844 | 1.440 |
| `comper_gasto` | 1.412 | 1.050 |
| `emper_barrio_pct_rec_tercil` | 1.032 | 770 |
| `emper_ep_pct_rec_tercil` | 173 | 83 |
| `emper_casa_pct_rec_tercil` | 112 | 45 |
| `comgen_per_pct_rec_tercil` | 105 | 50 |
| `comper_pct_rec_tercil` | 39 | 2 |

Suma de `n_solo` = 5.622 de 6.365 → solo 743 casos tienen `NA` en más de una
variable.

### A.3 Marca "ninguna"

- `comgen_medidas_na == 1`: **6.006** → `comgen_per_pct = 10`
- `comgen_vecinos_medidas_na == 1`: **17.255** → `comgen_com_pct = 11,1`
- Solo **1** caso en toda la base tiene `comgen_per_pct = 0`
- Total con `comgen_per_pct = 10`: 20.936 (6.006 "ninguna" + 14.930 "una medida")

### A.4 Tamaños de cluster

| | C1 | C2 | C3 | C4 | C5 | C6 | NA |
|---|---|---|---|---|---|---|---|
| `clusters_4` | 16.790 | 8.244 | 11.385 | 13.012 | — | — | 6.365 |
| `clusters_5` | 7.076 | 9.714 | 8.244 | 11.385 | 13.012 | — | 6.365 |
| `clusters_6` | 7.076 | 9.714 | 8.244 | 11.385 | 5.846 | 7.166 | 6.365 |

### A.5 `85` a nivel de ítem (batería de lugares, Kish==1)

| Ítem | N en 85 |
|---|---|
| 15 lugar de estudio | 48.229 |
| 6 Metro/Biotrén | 30.716 |
| 9 terminal aéreo | 29.757 |
| 5 apps (Uber etc.) | 24.105 |
| 14 lugar de trabajo | 21.918 |
| 1 vehículo propio | 21.672 |

`COSTOS_MEDIDAS`: 29.312 en `85`, 1 caso en `96`.

### A.6 Índices secundarios

- Desórdenes: 8 ítems · 6.563 casos con ≥1 en `88`/`99` · 17 con los 8 → índice 0
- Incivilidades: 7 ítems · 1.839 con ≥1 · 20 con los 7 → índice 0
- Rango con todos los ítems válidos: 8–40 (desórdenes)
- Terciles: 18.599 / 18.599 / 18.598

### A.7 Repo

- Tamaño total: 61,7 MB
- `output/models/mca_hcpc_456.RData`: 26,5 MB (caché reconstruible)
- Entorno: R 4.5.2 · `renv` 1.2.3 disponible · `FactoMineR` 2.13 ·
  `targets`, `tarchetypes`, `crew`, `GDAtools` **no instalados**

---

## Anexo B — Trampas al diagnosticar

Para quien verifique estos números con scripts sueltos.

**`zap_labels()` significa cosas distintas según el paquete.**
`haven::zap_labels()` saca el atributo y **conserva los valores**.
`sjlabelled::zap_labels()` **convierte a `NA` los valores etiquetados**. Si ambos
están cargados gana el último del `search()` path. Cargar `sjlabelled` después de
`haven` y usar `zap_labels()` sin calificar hace que **una columna etiquetada
aparezca como 100% `NA`** y lleva a concluir que el pipeline destruyó los datos.
Usar siempre `haven::zap_labels()` calificado.

**`. %in% c(85, 88, 99)` sobre `haven_labelled` falla sin `sjlabelled` cargado**
(`vctrs` no sabe castear a character).

**`table()` sobre `haven_labelled` falla** con `Can't convert <haven_labelled> to
<character>`. Envolver en `haven::zap_labels()`.
