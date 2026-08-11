#*******************************************************************************
# Inventario de códigos especiales (Fase 2, PLAN.md)
# Institución: PNUD
# Resumen ejecutivo: una fila por combinación de batería fuente x código
# especial (85/88/96/99/77). Cierra formalmente el hallazgo de PLAN.md §1.
#*******************************************************************************
#
# Los N se calcularon el 11 de agosto de 2026 sobre `datos_seleccionados`
# (target verificado idéntico a input/data/proc/2025/enusc_1_select.RDS en la
# Fase 1) — es decir, sobre los datos ANTES de cualquier tratamiento de
# códigos especiales, para contar la ocurrencia cruda tal como llega de
# ENUSC. Para baterías multi-ítem (tipo A), N = casos con AL MENOS UN ítem en
# ese código. Para baterías de una sola columna (tipo B) y las columnas
# hermanas de las de tipo C, N = conteo directo.
#
# Los N de COSTOS_MEDIDAS (85=29.312, 96=1), MEDIDAS_NA (6.006) y
# VECINOS_MEDIDAS_NA (17.255) coinciden exactamente con el Anexo A del plan:
# no se recalcularon, se usaron tal cual. El resto de los N no está en el
# Anexo A (que no baja a este nivel de detalle) y se calculó de nuevo aquí,
# no reemplaza ningún número ya verificado.

library(dplyr)
library(readr)

inventario <- tibble::tribble(
    ~variable, ~codigo, ~n, ~significado, ~decision, ~justificacion,

    # --- Tipo A: P_INSEG_* (emper) ---------------------------------------
    "P_INSEG_LUGARES", "85", 55066,
    "No aplica: la persona no frecuenta ese lugar o situación (ej. no va a aeropuertos, no usa Metro)",
    "mantener",
    "Confirmado por el equipo (11-ago-2026): es un 'no aplica' genuino, no la ambigüedad de auto-censura por miedo que se había planteado como hipótesis en F2.1. Se excluye del denominador en create_var_pct() y así se mantiene.",

    "P_INSEG_LUGARES", "88", 1876,
    "No sabe", "mantener",
    "Convención D6, cerrada: queda en el denominador de emper_ep_pct, nunca cuenta como éxito.",

    "P_INSEG_LUGARES", "99", 135,
    "No responde", "mantener",
    "Convención D6, cerrada.",

    "P_INSEG_LUGARES", "96", 0,
    "Sin dato (declarado en las etiquetas del instrumento)", "mantener",
    "Declarado pero ausente en ENUSC 2025 (F2.2: '96 es un agujero latente'). Verificar en cada ola nueva antes de asumir que sigue en 0 (regla #6).",

    "P_INSEG_OSCURO", "85", 6466,
    "No aplica, misma lectura que P_INSEG_LUGARES (extendida por el mismo mecanismo de pregunta-filtro; no reconfirmada caso por caso por el equipo)",
    "mantener",
    "Estructuralmente idéntico a P_INSEG_LUGARES (gate 'no aplica' + Likert). Se extiende la lectura confirmada arriba; si el equipo quiere revisarla por separado, avisar.",

    "P_INSEG_OSCURO", "88", 145, "No sabe", "mantener", "Convención D6.",
    "P_INSEG_OSCURO", "99", 9, "No responde", "mantener", "Convención D6.",
    "P_INSEG_OSCURO", "96", 0, "Sin dato (declarado)", "mantener", "Declarado, ausente en 2025.",

    "P_INSEG_DIA", "85", 1225,
    "No aplica, misma lectura que P_INSEG_LUGARES (extendida, no reconfirmada por separado)",
    "mantener",
    "Ídem P_INSEG_OSCURO.",

    "P_INSEG_DIA", "88", 46, "No sabe", "mantener", "Convención D6.",
    "P_INSEG_DIA", "99", 14, "No responde", "mantener", "Convención D6.",
    "P_INSEG_DIA", "96", 0, "Sin dato (declarado)", "mantener", "Declarado, ausente en 2025.",

    # --- Tipo A: P_MOD_ACTIVIDADES (comper) ------------------------------
    "P_MOD_ACTIVIDADES", "85", 43028,
    "No aplica: la persona no realiza esa actividad (ej. no anda en efectivo, no tiene vehículo que estacionar)",
    "mantener",
    "Mismo mecanismo de pregunta-filtro que P_INSEG_LUGARES; se extiende la lectura confirmada por el equipo. N alto (77% de la muestra en al menos un ítem) porque son 13 actividades heterogéneas y es normal no practicar varias.",

    "P_MOD_ACTIVIDADES", "88", 708, "No sabe", "mantener", "Convención D6.",
    "P_MOD_ACTIVIDADES", "99", 86, "No responde", "mantener", "Convención D6.",
    "P_MOD_ACTIVIDADES", "96", 0, "Sin dato (declarado)", "mantener", "Declarado, ausente en 2025.",

    # --- Tipo A: P_DESORDENES / P_INCIVILIDADES (sin 85 en el diseño) ----
    "P_DESORDENES", "88", 6485, "No sabe", "mantener*",
    "*Convención vigente en create_var_pct() para _pct, PERO desordenes_ind NO usa create_var_pct(): usa rowSums(na.rm=TRUE), que es D5 (recomendada, no aplicada en esta fase). Ver PLAN.md D5.",

    "P_DESORDENES", "99", 115, "No responde", "mantener*",
    "Mismo comentario que 88: la convención real hoy es D5 (na.rm=TRUE), no D6. Se resuelve en Fase 3.",

    "P_INCIVILIDADES", "88", 1788, "No sabe", "mantener*",
    "Mismo caso que P_DESORDENES: hoy tratado con D5 (na.rm=TRUE), no D6.",

    "P_INCIVILIDADES", "99", 64, "No responde", "mantener*",
    "Mismo caso que P_DESORDENES.",

    # --- Tipo B: una columna ----------------------------------------------
    "P_EXPOS_DELITO", "88", 2343, "No sabe", "mantener",
    "Alimenta perper_delito categoría 4 (si ambos ítems del gate están en 88/99) y categoría 5 (D3, no corregida en esta fase).",

    "P_EXPOS_DELITO", "99", 46, "No responde", "mantener",
    "Ídem: alimenta perper_delito categorías 4/5 (D3).",

    "COSTOS_MEDIDAS", "85", 29312,
    "No tiene medidas de seguridad → gasto = 0", "mantener",
    "Ya aplica el criterio correcto de PLAN.md §1 (85 conservado como respuesta sustantiva, no como NA). Es el precedente citado para D1. N idéntico al Anexo A.5.",

    "COSTOS_MEDIDAS", "88", 1298, "No sabe", "mantener",
    "case_when() lo preserva como categoría 88 en comper_gasto (no lo pasa a NA ni lo pliega a otra categoría).",

    "COSTOS_MEDIDAS", "96", 1, "Sin dato", "fix pendiente (Fase 3)",
    "El case_when de comper_gasto (1:5->1, 85->0, 88->88, 99->99) NO contempla 96: cae al TRUE~NA final. Es el 'NA misterioso' de F2.1/2_recode.R. Fix de una línea, ya identificado; se aplica en Fase 3, no acá. N idéntico al Anexo A.5.",

    "COSTOS_MEDIDAS", "99", 113, "No responde", "mantener",
    "case_when() lo preserva como categoría 99 en comper_gasto.",

    "P_FUENTE_INFO_PAIS", "77", 335,
    "Otro (canal de información no listado, respuesta sustantiva)",
    "hallazgo nuevo, no evaluado en Fase 3",
    "4_add_vars.R:94 trae un case_when con la rama 77 COMENTADA y la nota '#! El otro quedará dentro de la categoría 0!': hoy alguien que respondió 'Otro' cae en info_exp_personal=0, info_otras_personas=0, etc. para las 5 variables info_*, indistinguible de quien no se informa por ningún canal listado. No está en D1-D6; se documenta acá porque el inventario es el lugar para que no quede invisible (regla #6). Requiere decisión: ¿corresponde una sexta categoría info_otro, o se deja como está?",

    "P_FUENTE_INFO_PAIS", "88", 198, "No sabe", "mantener",
    "Cubierto por el case_when de construir_vars_info(): if_all(...==88)~88.",

    "P_FUENTE_INFO_PAIS", "99", 35, "No responde", "mantener",
    "Cubierto por el case_when de construir_vars_info(): if_all(...==99)~99.",

    "P_FUENTE_INFO_COM", "77", 321,
    "Otro (canal de información no listado, respuesta sustantiva)",
    "hallazgo nuevo, no evaluado en Fase 3",
    "Mismo caso que P_FUENTE_INFO_PAIS: 77 queda plegado a 0 en las cinco variables info_*.",

    "P_FUENTE_INFO_COM", "88", 442, "No sabe", "mantener", "Ídem P_FUENTE_INFO_PAIS.",
    "P_FUENTE_INFO_COM", "99", 61, "No responde", "mantener", "Ídem P_FUENTE_INFO_PAIS.",

    "P_FUENTE_INFO_BARRIO", "77", 312,
    "Otro (canal de información no listado, respuesta sustantiva)",
    "hallazgo nuevo, no evaluado en Fase 3",
    "Mismo caso que P_FUENTE_INFO_PAIS: 77 queda plegado a 0 en las cinco variables info_*. De las tres P_FUENTE_INFO_*, esta es la que más casos aporta a info_rrss/info_prensa/info_tv (son las variables que más se calculan desde esta fuente).",

    "P_FUENTE_INFO_BARRIO", "88", 607, "No sabe", "mantener", "Ídem P_FUENTE_INFO_PAIS.",
    "P_FUENTE_INFO_BARRIO", "99", 85, "No responde", "mantener", "Ídem P_FUENTE_INFO_PAIS.",

    # --- Tipo C: columna propia --------------------------------------------
    "MEDIDAS", "85 (columna _NA)", 6006,
    "'Ninguna medida' — respuesta sustantiva (0% de adopción), no ausencia de dato",
    "mantener conservada como respuesta",
    "Es el hallazgo central de PLAN.md §1. El repo viejo la codificaba como 85 genérico y la perdía en el drop_na(); el fix ya aplicado la conserva. Pendiente D1: hoy además se cuenta como si fuera 'una medida más' en el denominador de comgen_per_pct (infla el % a 10% en vez de 0%) — eso se corrige en Fase 3, acá solo se documenta que la columna existe y qué significa. N idéntico al Anexo A.3.",

    "MEDIDAS", "88 (columna _NS)", 36, "No sabe", "mantener",
    "Ausencia de respuesta genuina, columna hermana de _NA pero estructuralmente distinta (ver PLAN.md §4.3).",

    "MEDIDAS", "99 (columna _NR)", 69, "No responde", "mantener",
    "Ausencia de respuesta genuina, columna hermana de _NA.",

    "MEDIDAS", "96 (valor suelto en cualquier columna)", 1,
    "Sin dato: la batería completa (las 9 sustantivas + _NA/_NS/_NR) llegó codificada 96 en vez de 0/1",
    "hallazgo nuevo, no evaluado en Fase 3",
    "Un único caso (rph_id 110962_P3) tiene 96 en las 12 columnas de MEDIDAS y las 11 de VECINOS_MEDIDAS a la vez: es un bloque de pregunta entero sin dato, no un ítem suelto. Con el tratamiento actual (success.cats=1), ese caso queda con comgen_per_pct=0% y comgen_com_pct=0%, indistinguible de alguien que sí respondió 'ninguna medida'. Un solo caso, impacto mínimo, pero conviene decidir si se excluye o se deja así.",

    "VECINOS_MEDIDAS", "85 (columna _NA)", 17255,
    "'Ninguna medida comunitaria' — respuesta sustantiva, no ausencia de dato",
    "mantener conservada como respuesta",
    "Mismo hallazgo que MEDIDAS x 85, para la batería comunitaria. Pendiente D1 (ver arriba). N idéntico al Anexo A.3.",

    "VECINOS_MEDIDAS", "88 (columna _NS)", 1793, "No sabe", "mantener",
    "Columna hermana de _NA, estructuralmente distinta.",

    "VECINOS_MEDIDAS", "99 (columna _NR)", 51, "No responde", "mantener",
    "Columna hermana de _NA.",

    "VECINOS_MEDIDAS", "96 (valor suelto en cualquier columna)", 1,
    "Sin dato: mismo caso único que en MEDIDAS x 96 (mismo respondiente, ambas baterías a la vez)",
    "hallazgo nuevo, no evaluado en Fase 3",
    "Ver justificación de MEDIDAS x 96: es el mismo rph_id, las dos baterías del bloque MDC2/MDC4 completo.",

    "P_DELITO_PRONOSTICO", "77 (columna __77)", 375,
    "Cree que será víctima de otro tipo de delito — respuesta sustantiva",
    "mantener",
    "D3: hoy if_any(pronostico_{77,88,99})~5 mezcla esta respuesta sustantiva con no-respuesta genuina en una sola categoría de perper_delito. No se corrige en esta fase (F1.0); D3 recomienda separarla en Fase 3.",

    "P_DELITO_PRONOSTICO", "88 (columna __88)", 64, "No sabe", "mantener",
    "Mismo mecanismo D3: hoy mezclado con 77 y 99 en la categoría 5.",

    "P_DELITO_PRONOSTICO", "99 (columna __99)", 8, "No responde", "mantener",
    "Mismo mecanismo D3.",

    "P_DELITO_PRONOSTICO", "96 (valor suelto)", 0,
    "Sin dato (declarado)", "mantener",
    "Declarado, ausente en 2025. Nota aparte: 26.315 de 55.796 tienen esta batería completa en NA por diseño del cuestionario (skip pattern: solo se pregunta si P_EXPOS_DELITO=1), lo cual es distinto de un código especial — no es un 'código' en el sentido de este inventario, es la estructura del salto de pregunta."
)

readr::write_csv(inventario, "output/tables/2025/inventario_codigos.csv")

cat("Filas:", nrow(inventario), "\n")
cat("Celdas vacías en decision:", sum(inventario$decision == "" | is.na(inventario$decision)), "\n")
sin_just <- inventario |> dplyr::filter(decision != "mantener", (justificacion == "" | is.na(justificacion)))
cat("Decisiones != 'mantener' sin justificación:", nrow(sin_just), "\n")
