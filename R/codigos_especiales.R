#' Recuperar `85`/`88`/`99` en las variables recodificadas
#'
#' Reemplaza `2_recode.R:172-181` (el `case_when` de NS/NR de `comgen`,
#' basado en sus columnas hermanas `_ns`/`_nr`) y `2_recode.R:197-223` (la
#' recuperación genérica: cuando TODOS los ítems fuente de una batería
#' comparten el mismo código especial, ese código se reimputa en la variable
#' `_cat`, que de otro modo habría quedado en `NA` por el `ntile()`).
#'
#' El segundo bloque es un no-op para `comgen_per`/`comgen_com` — sus ítems
#' fuente son columnas dummy `0`/`1` que nunca valen `85`/`88`/`99` — pero se
#' incluye igual, tal como en el original, porque el bloque genérico no las
#' excluye.
#'
#' @param datos Datos ya categorizados en terciles.
#' @param spec `cfg$INDICES`: ítems fuente por batería (para el bloque
#'   genérico).
#' @param codigos `cfg$CODIGOS_COMGEN`: qué columna `_ns`/`_nr`/`_na` de cada
#'   batería corresponde a cada variable del modelo.
#' @return `datos` con los códigos especiales recuperados en las columnas
#'   `_cat`.
recuperar_codigos_especiales <- function(datos, spec, codigos) {
    #* El mapeo llega declarado en `cfg$CODIGOS_COMGEN` y no se escribe acá,
    #* para que construir_metadata() pueda decir a qué variable alimenta cada
    #* columna `_ns`/`_nr` en vez de reportarlas como no usadas.
    for (destino in names(codigos)) {
        marcas <- codigos[[destino]]
        datos[[destino]] <- dplyr::case_when(
            datos[[marcas[["ns"]]]] == 1 ~ 88,
            datos[[marcas[["nr"]]]] == 1 ~ 99,
            TRUE ~ datos[[destino]]
        )
    }

    excluir <- c("perper_delito", "comper_gasto")
    spec_torec <- spec[!names(spec) %in% excluir]
    #* Todo lo que queda produce una `_cat`, así que el nombre se deriva igual
    #* que en categorizar_indices().
    names(spec_torec) <- paste0(names(spec_torec), "_cat")

    purrr::reduce2(
        names(spec_torec),
        spec_torec,
        \(data, rec_var, dim_vars) {
            data |>
                dplyr::mutate(
                    "{rec_var}" := dplyr::case_when(
                        dplyr::if_all(dplyr::all_of(dim_vars), ~ . == 85) ~
                            85,
                        dplyr::if_all(dplyr::all_of(dim_vars), ~ . == 88) ~
                            88,
                        dplyr::if_all(dplyr::all_of(dim_vars), ~ . == 99) ~
                            99,
                        TRUE ~ .data[[rec_var]]
                    )
                )
        },
        .init = datos
    )
}

