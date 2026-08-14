
#' Construir una variable de porcentaje a partir de una batería de ítems
#'
#' Helper sin cambios respecto de `processing/helpers/functions.R`. Para cada
#' caso calcula qué porcentaje de los ítems válidos de una batería recibió
#' alguna de las categorías "éxito"; los ítems en `85` ("No aplica") se
#' excluyen del denominador. `88` y `99` se quedan en el denominador — es la
#' convención D6, deliberada y no se toca acá (ver PLAN.md D6).
#'
#' @param data Data frame con la columna identificadora y los ítems fuente.
#' @param id.col Columna identificadora, sin comillas.
#' @param success.cats Categorías que cuentan como éxito.
#' @param source.cols Ítems fuente de la batería.
#' @param name.var.pct Nombre de la variable nueva, como string.
#' @param output Qué devolver: `"data"`, `"details"`, `"insumo"` o `"all"`.
#' @return Según `output`; por defecto `data` con la variable nueva agregada.
create_var_pct <- function(
    data,
    id.col = rph_id,
    success.cats,
    source.cols,
    name.var.pct,
    output = c("data", "details", "insumo", "all")
) {
    output <- match.arg(output)

    details <- data |>
        dplyr::select({{ id.col }}, {{ source.cols }}) |>
        tidyr::pivot_longer(
            cols = {{ source.cols }},
            names_to = "variable",
            values_to = "value"
        ) |>
        dplyr::group_by({{ id.col }}) |>
        dplyr::mutate(
            not_valid = sum(dplyr::if_else(value == 85, 1, 0)),
            n_valid = dplyr::n() - not_valid,
            n_success = sum(dplyr::if_else(value %in% success.cats, 1, 0)),
            "{name.var.pct}" := (n_success / n_valid) * 100
        ) |>
        dplyr::ungroup() |>
        dplyr::select(-not_valid)

    n_sin_validos <- details |>
        dplyr::filter(n_valid == 0) |>
        dplyr::distinct({{ id.col }}) |>
        nrow()

    if (n_sin_validos > 0) {
        message(glue::glue(
            "  · {name.var.pct}: {n_sin_validos} caso(s) sin ningún ítem válido (todos 85) -> NaN, ",
            "se imputan a 85 más adelante"
        ))
    }

    insumo <- details |>
        dplyr::select({{ id.col }}, {{ name.var.pct }}) |>
        dplyr::distinct({{ id.col }}, .keep_all = TRUE)

    data <- data |> dplyr::left_join(insumo)

    if (output == "data") {
        return(data)
    } else if (output == "details") {
        return(details)
    } else if (output == "insumo") {
        return(insumo)
    } else if (output == "all") {
        return(list(data = data, details = details, insumo = insumo))
    }
}

#' Construir los seis índices `_pct`
#'
#' Reemplaza las seis llamadas a `create_var_pct()` de `2_recode.R:82-130`
#' (sin contar los `case_when` de `perper_delito` y `comper_gasto`, que son
#' funciones propias). Vive acá D1: qué columnas entran en `source.cols` de
#' cada batería — **aplicada** (PLAN.md D1): `cfg$INDICES` ya no incluye las
#' columnas `_na` de `comgen` como una medida más, así que "ninguna medida"
#' da 0% en vez de 10%/11,1%.
#'
#' @param datos Datos con las columnas fuente.
#' @param spec `cfg$INDICES`: ítems fuente por batería.
#' @return `datos` con las seis columnas `_pct` agregadas.
construir_indices_pct <- function(datos, spec) {
    #* Los dos índices de comgen salieron de acá en agosto de 2026: sus baterías
    #* no admiten el código 85, así que el denominador es constante y el
    #* porcentaje no aportaba nada sobre el conteo. Se categorizan directo desde
    #* los ítems en categorizar_indices(). Los cuatro que quedan sí tienen
    #* denominador variable y el porcentaje normaliza sobre lo aplicable.
    datos <- create_var_pct(
        datos,
        success.cats = c(1, 2),
        source.cols = spec[["emper_ep_pct"]],
        name.var.pct = "emper_ep_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = c(1, 2),
        source.cols = spec[["emper_barrio_pct"]],
        name.var.pct = "emper_barrio_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = c(1, 2),
        source.cols = spec[["emper_casa_pct"]],
        name.var.pct = "emper_casa_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = 1,
        source.cols = spec[["comper_pct"]],
        name.var.pct = "comper_pct"
    )
    datos
}

#' Categoría de expectativa de victimización (`perper_delito`)
#'
#' Reemplaza el `case_when` de `2_recode.R:97-106`. Vive acá D3, **aplicada**
#' (PLAN.md D3): la vieja categoría 5 mezclaba "otro delito" (`77`,
#' sustantivo) con no-respuesta (`88`/`99`). Queda separada en dos: la
#' categoría 5 es ahora solo "otro delito" (se conserva en el modelo) y la 6
#' es "no sabe/no responde" (se sigue excluyendo en
#' `preparar_datos_mca()`, que pasó de `c(4, 5)` a `c(4, 6)`).
#'
#' @section Sobre la predicción falsable del plan:
#' PLAN.md predecía que aplicar D3 sola subiría el N del MCA en 2.182 casos
#' (el `n_solo` de `perper_delito` del Anexo A.2), para un total de 51.613.
#' Verificado sobre los datos reales, la vieja categoría 5 tenía solo **150**
#' casos en total (no 2.182): **78** marcaron *únicamente* "77 = otro delito"
#' (sin ningún delito específico) — esos son los que rescata D3, de los
#' cuales 72 entran efectivamente al modelo (6 quedan fuera por otra
#' variable) — y **72** marcaron *únicamente* no sabe/no responde, que
#' siguen excluidos. La diferencia con la predicción del plan es que
#' `P_DELITO_PRONOSTICO` es una pregunta de "marque todas": de las 375
#' personas que marcaron "77", 297 marcaron además un delito específico y ya
#' caían en la categoría 2 o 3 (evaluadas antes que la 5 en el `case_when`),
#' tanto antes como después de este cambio. El grueso del `n_solo = 2.182`
#' es la categoría 4 (`expos_delito` en 88/99, la pregunta-gate anterior),
#' que D3 no toca. La predicción del plan estaba mal, no la implementación.
#'
#' @param datos Datos con las columnas fuente de `perper_delito`.
#' @return `datos` con la columna `perper_delito` agregada (6 categorías).
construir_perper_delito <- function(datos) {
    datos |>
        dplyr::mutate(
            perper_delito = dplyr::case_when(
                dplyr::if_all("perper_p_expos_delito", ~ . == 2) ~ 1,
                dplyr::if_any(
                    paste0("perper_p_delito_pronostico_", c(1:4, 6, 9:11)),
                    ~ . == 1
                ) ~
                    2,
                dplyr::if_any(
                    paste0("perper_p_delito_pronostico_", c(5, 7:8)),
                    ~ . == 1
                ) ~
                    3,
                dplyr::if_all("perper_p_expos_delito", ~ . %in% c(88, 99)) ~ 4,
                dplyr::if_any(
                    "perper_p_delito_pronostico_77",
                    ~ . == 1
                ) ~
                    5,
                dplyr::if_any(
                    paste0("perper_p_delito_pronostico_", c(88, 99)),
                    ~ . == 1
                ) ~
                    6,
                TRUE ~ NA
            )
        )
}

#' Gasto en medidas de seguridad (`comper_gasto`)
#'
#' Reemplaza el `case_when` de `2_recode.R:112-120`. El `case_when` no cubre
#' el código `96` (F2.1): un caso con `96` cae al `TRUE ~ NA` final. No se
#' corrige en esta fase (ver F1.0).
#'
#' @param datos Datos con la columna `comper_costos_medidas`.
#' @return `datos` con la columna `comper_gasto` agregada.
construir_comper_gasto <- function(datos) {
    datos |>
        dplyr::mutate(
            comper_gasto = dplyr::case_when(
                dplyr::if_all("comper_costos_medidas", ~ . %in% c(1:5)) ~ 1,
                dplyr::if_all("comper_costos_medidas", ~ . == 85) ~ 0,
                dplyr::if_all("comper_costos_medidas", ~ . == 88) ~ 88,
                dplyr::if_all("comper_costos_medidas", ~ . == 99) ~ 99,
                TRUE ~ NA
            )
        )
}


#' Cuántas situaciones le aplican a cada persona en los índices de dos ítems
#'
#' Diagnóstico de un supuesto que el método `"valor"` deja implícito.
#'
#' @section Qué problema mide:
#' `emper_barrio_pct` y `emper_casa_pct` se construyen con dos ítems, "de día" y
#' "cuando ya está oscuro", y se categorizan por el valor del índice (0, 50 o
#' 100). Eso da por sentado que a todo el mundo le aplican los dos momentos,
#' pero los ítems admiten el código 85 y a mucha gente le aplica uno solo:
#' `create_var_pct()` normaliza sobre lo aplicable, así que quien declara
#' inseguridad en su único momento aplicable llega a 100 y cae en la misma
#' categoría que quien la declara en los dos.
#'
#' El cálculo es consistente con la convención del proyecto (normalizar sobre lo
#' aplicable, igual que en espacio público y en prácticas). Lo que no calza es la
#' etiqueta de la categoría 3, que afirma "de día y de noche" para gente con un
#' solo momento observado.
#'
#' @section Por qué es un target y no un chunk:
#' Para que la página pueda citar las cifras sin calcularlas, y para que el
#' diagnóstico se rehaga solo cuando cambie la versión de la encuesta. La
#' proporción de casos con un ítem no aplicable puede moverse entre años.
#'
#' @param datos_sel `datos_seleccionados`, con los ítems originales.
#' @param datos_cat Datos con las columnas `_cat` ya construidas.
#' @param spec `cfg$INDICES`, para saber qué ítems componen cada índice.
#' @param cortes `cfg$CORTES`, para quedarse con los de método `"valor"`.
#' @return Un tibble `indice | n_aplica | categoria | n`.
medir_aplicabilidad <- function(datos_sel, datos_cat, spec, cortes) {
    vars <- names(cortes)[
        vapply(cortes, \(s) s$metodo == "valor", logical(1))
    ]

    stopifnot(
        "medir_aplicabilidad(): ningún índice usa el método 'valor'" = length(
            vars
        ) >
            0
    )

    purrr::map(vars, function(v) {
        m <- vapply(
            datos_sel[spec[[v]]],
            \(x) as.numeric(haven::zap_labels(x)),
            numeric(nrow(datos_sel))
        )
        #* `n_valid` en create_var_pct() descuenta solo el 85: los otros códigos
        #* especiales cuentan en el denominador como no adhesión.
        n_aplica <- rowSums(m != 85)
        categoria <- as.numeric(haven::zap_labels(
            datos_cat[[paste0(v, "_cat")]]
        ))

        tibble::tibble(indice = v, n_aplica = n_aplica, categoria = categoria) |>
            dplyr::filter(categoria %in% 1:3) |>
            dplyr::count(indice, n_aplica, categoria)
    }) |>
        purrr::list_rbind()
}
