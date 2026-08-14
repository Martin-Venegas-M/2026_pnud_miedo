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
#' @param spec `spec_indices`: ítems fuente por batería (para el bloque
#'   genérico).
#' @return `datos` con los códigos especiales recuperados en las columnas
#'   `_cat`.
recuperar_codigos_especiales <- function(datos, spec) {
    #* El mapeo se declara en spec_codigos_comgen() y no se escribe acá, para
    #* que construir_metadata() pueda decir a qué variable alimenta cada columna
    #* `_ns`/`_nr` en vez de reportarlas como no usadas.
    for (destino in names(spec_codigos_comgen())) {
        marcas <- spec_codigos_comgen()[[destino]]
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

#' Columnas de código especial de las baterías de `comgen`
#'
#' Las preguntas de opción múltiple guardan "ninguna", "no sabe" y "no responde"
#' como **columnas propias**, estructuralmente idénticas a las de las medidas.
#' Este spec declara cuál es cuál y a qué variable del modelo corresponde cada
#' grupo.
#'
#' @section Por qué existe como declaración y no dentro del `case_when`:
#' [recuperar_codigos_especiales()] las usaba escritas a mano, y como no
#' aparecían en `spec_indices`, [construir_metadata()] las reportaba con uso
#' "No se usa". Eso era falso para `_ns` y `_nr`, que son lo único que separa a
#' quien no respondió de quien respondió "ninguna medida", y engañoso para
#' `_na`, cuyo tratamiento es la decisión que originó este repositorio.
#'
#' @section Los tres roles:
#' - `ns` y `nr` **se leen**: estampan los códigos 88 y 99 sobre la variable
#'   categorizada, después de categorizar.
#' - `na` **no se lee, y esa es la decisión (D1)**. Quien marca "ninguna medida"
#'   tiene todas las columnas de medidas en 0, así que el conteo le da 0 por
#'   aritmética, sin necesidad de mirar esta columna. Incluirla en la batería
#'   era el error original: contaba como una medida más y "ninguna" nunca daba
#'   cero.
#'
#' @return Una lista nombrada por variable del modelo, con las columnas `ns`,
#'   `nr` y `na` de su batería.
spec_codigos_comgen <- function() {
    list(
        comgen_per_cat = c(
            ns = "comgen_medidas_ns",
            nr = "comgen_medidas_nr",
            na = "comgen_medidas_na"
        ),
        comgen_com_cat = c(
            ns = "comgen_vecinos_medidas_ns",
            nr = "comgen_vecinos_medidas_nr",
            na = "comgen_vecinos_medidas_na"
        )
    )
}
