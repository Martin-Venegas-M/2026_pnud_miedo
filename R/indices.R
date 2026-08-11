#' Especificación de los ítems fuente de cada índice
#'
#' Reemplaza `rec_vars` de `2_recode.R:42-78`. Es el target `spec_indices`:
#' cambiarlo invalida todo lo que se construye a partir de él (D1 y D4 viven
#' acá).
#'
#' @return Una lista nombrada, un elemento por índice. `perper_delito` es una
#'   lista anidada: cada elemento son los ítems fuente de una de las cinco
#'   ramas de su `case_when` (ver `construir_perper_delito()`).
construir_spec_indices <- function() {
    list(
        emper_ep_pct = paste0("emper_p_inseg_lugares_", 1:11),
        emper_barrio_pct = c("emper_p_inseg_oscuro_1", "emper_p_inseg_dia_1"),
        emper_casa_pct = c("emper_p_inseg_oscuro_2", "emper_p_inseg_dia_2"),
        perper_delito = list(
            "perper_p_expos_delito",
            paste0("perper_p_delito_pronostico_", c(1:4, 6, 9:11)),
            paste0("perper_p_delito_pronostico_", c(5, 7:8)),
            "perper_p_expos_delito",
            paste0("perper_p_delito_pronostico_", c(77, 88, 99))
        ),
        comper_pct = paste0("comper_p_mod_actividades_", 1:13),
        comper_gasto = c("comper_costos_medidas"),
        comgen_per_pct = c(
            "comgen_medidas_perro",
            "comgen_medidas_alarma_privada",
            "comgen_medidas_camaras_vigilancia",
            "comgen_medidas_rejas",
            "comgen_medidas_cerco",
            "comgen_medidas_proteccion",
            "comgen_medidas_seguro",
            "comgen_medidas_foco",
            "comgen_medidas_otro",
            "comgen_medidas_na"
        ),
        comgen_com_pct = c(
            "comgen_vecinos_medidas_whatsapp",
            "comgen_vecinos_medidas_vigilancia",
            "comgen_vecinos_medidas_al_comunit",
            "comgen_vecinos_medidas_coord_pol",
            "comgen_vecinos_medidas_coord_mun",
            "comgen_vecinos_medidas_televig",
            "comgen_vecinos_medidas_privad",
            "comgen_vecinos_medidas_otro",
            "comgen_vecinos_medidas_na"
        )
    )
}

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
#' cada batería — hoy `spec` incluye las columnas `_na` de `comgen` como una
#' medida más, que es exactamente el hallazgo de PLAN.md D1. No se corrige en
#' esta fase (ver F1.0).
#'
#' @param datos Datos con las columnas fuente.
#' @param spec `spec_indices`: ítems fuente por batería.
#' @return `datos` con las seis columnas `_pct` agregadas.
construir_indices_pct <- function(datos, spec) {
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
    datos <- create_var_pct(
        datos,
        success.cats = 1,
        source.cols = spec[["comgen_per_pct"]],
        name.var.pct = "comgen_per_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = 1,
        source.cols = spec[["comgen_com_pct"]],
        name.var.pct = "comgen_com_pct"
    )
    datos
}

#' Categoría de expectativa de victimización (`perper_delito`)
#'
#' Reemplaza el `case_when` de `2_recode.R:97-106`. Vive acá D3: la categoría 5
#' mezcla "otro delito" (`77`, sustantivo) con no-respuesta (`88`/`99`). No se
#' corrige en esta fase (ver F1.0).
#'
#' @param datos Datos con las columnas fuente de `perper_delito`.
#' @return `datos` con la columna `perper_delito` agregada.
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
                    paste0("perper_p_delito_pronostico_", c(77, 88, 99)),
                    ~ . == 1
                ) ~
                    5,
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

#' Pasar a `NA` los índices `comgen_*_pct` cuando la persona marcó NS/NR
#'
#' Reemplaza `2_recode.R:154-167`. El original usa `if_else()`; acá se usa
#' `replace(x, which(cond), NA)` por consistencia con la regla #1 — inocuo
#' porque `comgen_per_pct`/`comgen_com_pct` ya son numéricas puras en este
#' punto, sin atributo `labels` que perder.
#'
#' @param datos Datos con `comgen_per_pct`, `comgen_com_pct` y las columnas
#'   `_ns`/`_nr` de marca todas.
#' @return `datos` con esas dos columnas pasadas a `NA` donde corresponde.
marcar_no_respuesta_comgen <- function(datos) {
    vec_comgen_per <- c("comgen_medidas_ns", "comgen_medidas_nr")
    vec_comgen_com <- c("comgen_vecinos_medidas_ns", "comgen_vecinos_medidas_nr")

    marca_per <- Reduce(`|`, lapply(vec_comgen_per, \(v) datos[[v]] == 1))
    marca_com <- Reduce(`|`, lapply(vec_comgen_com, \(v) datos[[v]] == 1))

    datos$comgen_per_pct <- replace(
        datos$comgen_per_pct,
        which(marca_per),
        NA
    )
    datos$comgen_com_pct <- replace(
        datos$comgen_com_pct,
        which(marca_com),
        NA
    )

    datos
}
