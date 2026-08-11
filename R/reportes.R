#' Tabla marginal con `NA` como categoría explícita
#'
#' Base de `reportar_transformacion()`. Descarta etiquetas (importa el valor
#' crudo, no la etiqueta) usando `haven::zap_labels()` calificado — nunca
#' `sjlabelled::zap_labels()`, que convierte a `NA` los valores etiquetados
#' (ver PLAN.md Anexo B).
#'
#' @param x Vector a tabular.
#' @return Un tibble `valor | n | pct`, con una fila `"NA"` si corresponde.
tabla_marginal <- function(x) {
    if (inherits(x, "haven_labelled")) {
        x <- haven::zap_labels(x)
    }
    tibble::tibble(valor = x) |>
        dplyr::mutate(valor = dplyr::if_else(
            is.na(valor),
            "NA",
            as.character(valor)
        )) |>
        dplyr::count(valor, name = "n") |>
        dplyr::mutate(pct = round(n / sum(n) * 100, 2)) |>
        dplyr::arrange(valor)
}

#' Reporte de una transformación: forma, marginales y transiciones
#'
#' El reporte principal del sistema de log (PLAN.md §F1.5). Se ejecuta después
#' de cada target de datos, pareado con él.
#'
#' @param antes Datos antes de la transformación.
#' @param despues Datos después de la transformación.
#' @param vars Columnas a reportar. Puede ser un vector sin nombres (mismo
#'   nombre de columna en `antes` y `despues`) o un vector con nombres, donde
#'   el nombre es la columna en `antes` y el valor la columna en `despues`
#'   (para pasos donde la transformación también renombra, p.ej.
#'   `emper_ep_pct` -> `emper_ep_pct_rec_tercil`).
#' @param etiqueta Nombre del paso, para identificarlo en el CSV consolidado.
#'
#' @return Una lista con tres tibbles: `forma`, `marginales`, `transiciones`.
#'
#' @details
#' El bloque de transiciones es el que no existe en los `frq()` sueltos del
#' pipeline original: cruza el valor de origen contra el de destino por caso,
#' con `NA` como fila y columna explícitas del cruce (nunca filtrado), y se
#' reporta también cuando ambas variables tienen distinto número de
#' categorías. Solo se calcula cuando ambas columnas (origen y destino)
#' existen; si `vars` nombra una columna nueva que no existía en `antes`, esa
#' variable queda fuera de `transiciones` pero sí aparece en `marginales`.
reportar_transformacion <- function(antes, despues, vars, etiqueta) {
    if (is.null(names(vars)) || any(names(vars) == "")) {
        vars <- rlang::set_names(vars, vars)
    }

    forma <- tibble::tibble(
        etiqueta = etiqueta,
        filas_antes = nrow(antes),
        filas_despues = nrow(despues),
        cols_agregadas = length(setdiff(names(despues), names(antes))),
        cols_eliminadas = length(setdiff(names(antes), names(despues)))
    )

    marginales <- purrr::map2(
        names(vars),
        unname(vars),
        function(v_antes, v_despues) {
            m_antes <- if (v_antes %in% names(antes)) {
                tabla_marginal(antes[[v_antes]]) |>
                    dplyr::rename(n_antes = n, pct_antes = pct)
            } else {
                tibble::tibble(
                    valor = character(),
                    n_antes = integer(),
                    pct_antes = double()
                )
            }
            m_despues <- if (v_despues %in% names(despues)) {
                tabla_marginal(despues[[v_despues]]) |>
                    dplyr::rename(n_despues = n, pct_despues = pct)
            } else {
                tibble::tibble(
                    valor = character(),
                    n_despues = integer(),
                    pct_despues = double()
                )
            }
            dplyr::full_join(m_antes, m_despues, by = "valor") |>
                dplyr::mutate(
                    etiqueta = etiqueta,
                    variable_antes = v_antes,
                    variable_despues = v_despues
                ) |>
                dplyr::relocate(etiqueta, variable_antes, variable_despues)
        }
    ) |>
        purrr::list_rbind()

    transiciones <- purrr::map2(
        names(vars),
        unname(vars),
        function(v_antes, v_despues) {
            if (
                !(v_antes %in% names(antes)) || !(v_despues %in% names(despues))
            ) {
                return(NULL)
            }
            origen <- antes[[v_antes]]
            destino <- despues[[v_despues]]
            if (inherits(origen, "haven_labelled")) {
                origen <- haven::zap_labels(origen)
            }
            if (inherits(destino, "haven_labelled")) {
                destino <- haven::zap_labels(destino)
            }
            origen_f <- forcats::fct_na_value_to_level(
                factor(origen),
                "NA"
            )
            destino_f <- forcats::fct_na_value_to_level(
                factor(destino),
                "NA"
            )
            as.data.frame(table(origen = origen_f, destino = destino_f)) |>
                tibble::as_tibble() |>
                dplyr::filter(Freq > 0) |>
                dplyr::mutate(
                    etiqueta = etiqueta,
                    variable_antes = v_antes,
                    variable_despues = v_despues,
                    n = Freq
                ) |>
                dplyr::select(
                    etiqueta,
                    variable_antes,
                    variable_despues,
                    origen,
                    destino,
                    n
                )
        }
    ) |>
        purrr::list_rbind()

    list(forma = forma, marginales = marginales, transiciones = transiciones)
}

#' Reporte de pérdida muestral por variable
#'
#' Para los pasos que descartan casos (regla #5: reportar la pérdida
#' explícitamente). Distingue magnitud (`n_na`) de causa exclusiva (`n_solo`),
#' que es la que sirve para priorizar qué variable arreglar primero.
#'
#' @param antes Datos con las variables completas, antes de filtrar casos.
#' @param despues Datos después de filtrar (`filtrar_casos_completos()`).
#' @param vars Variables a evaluar (típicamente `cfg$VARS_REC_TERCIL`).
#' @param etiqueta Nombre del paso.
#' @param max_perdida Umbral de pérdida total (proporción, 0 a 1) a partir del
#'   cual el reporte falla. `NULL` hasta la Fase 5: fijarlo ahora sería
#'   calibrar contra números que la Fase 3 va a cambiar a propósito.
#'
#' @return Una lista con `resumen` (una fila) y `detalle` (una fila por
#'   variable, con `n_na` y `n_solo`).
reportar_perdida <- function(antes, despues, vars, etiqueta, max_perdida = NULL) {
    faltan <- is.na(antes[vars])
    n_por_caso <- rowSums(faltan)

    detalle <- tibble::tibble(
        etiqueta = etiqueta,
        variable = vars,
        n_na = colSums(faltan),
        n_solo = colSums(faltan & n_por_caso == 1)
    )

    n_antes <- nrow(antes)
    n_despues <- nrow(despues)
    n_eliminados <- n_antes - n_despues
    pct_eliminados <- n_eliminados / n_antes

    resumen <- tibble::tibble(
        etiqueta = etiqueta,
        n_antes = n_antes,
        n_despues = n_despues,
        n_eliminados = n_eliminados,
        pct_eliminados = round(pct_eliminados * 100, 2)
    )

    if (!is.null(max_perdida) && pct_eliminados > max_perdida) {
        stop(glue::glue(
            "reportar_perdida('{etiqueta}'): pérdida de {round(pct_eliminados * 100, 2)}% ",
            "supera el máximo aceptado ({round(max_perdida * 100, 2)}%)"
        ))
    }

    list(resumen = resumen, detalle = detalle)
}

#' Reporte de composición de los casos eliminados
#'
#' `reportar_perdida()` mide magnitud, no composición. Cruza los casos
#' eliminados contra variables sociodemográficas y compara su perfil con el
#' de los que quedan, para poder ver si la pérdida es sesgada (el hallazgo de
#' PLAN.md §1) y no solo grande.
#'
#' @param datos Datos con las variables secundarias, antes de filtrar casos.
#' @param eliminados Vector lógico, mismo largo y orden que `datos`: `TRUE`
#'   para los casos que `filtrar_casos_completos()` descarta.
#' @param vars_sec Variables a comparar (típicamente `cfg$VARS_SEC`).
#'
#' @return Un tibble largo: `variable | grupo | valor | n | pct`, donde `pct`
#'   es el porcentaje dentro de cada grupo (`incluido` / `eliminado`).
reportar_composicion <- function(datos, eliminados, vars_sec) {
    grupo <- dplyr::if_else(eliminados, "eliminado", "incluido")

    purrr::map(vars_sec, function(v) {
        if (!(v %in% names(datos))) {
            return(NULL)
        }
        valor <- datos[[v]]
        if (inherits(valor, "haven_labelled")) {
            valor <- haven::zap_labels(valor)
        }
        valor <- dplyr::if_else(is.na(valor), "NA", as.character(valor))

        tibble::tibble(variable = v, grupo = grupo, valor = valor) |>
            dplyr::count(variable, grupo, valor, name = "n") |>
            dplyr::group_by(grupo) |>
            dplyr::mutate(pct = round(n / sum(n) * 100, 2)) |>
            dplyr::ungroup()
    }) |>
        purrr::list_rbind()
}

#' Consolidar los targets de log en CSV
#'
#' @param logs Lista nombrada de reportes (salida de `reportar_transformacion()`
#'   o `reportar_perdida()`) a consolidar por bloque.
#' @param bloque Nombre del bloque dentro de cada reporte a extraer
#'   (`"forma"`, `"marginales"`, `"transiciones"`, `"resumen"`, `"detalle"`).
#' @param archivo Ruta de salida.
#' @return La ruta escrita, invisible.
escribir_log_csv <- function(logs, bloque, archivo) {
    tabla <- purrr::imap(logs, function(log, nombre) {
        x <- log[[bloque]]
        if (is.null(x) || nrow(x) == 0) {
            return(NULL)
        }
        x
    }) |>
        purrr::list_rbind()

    dir.create(dirname(archivo), recursive = TRUE, showWarnings = FALSE)
    readr::write_csv(tabla, archivo)
    invisible(archivo)
}
