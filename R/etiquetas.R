
#' Aplicar etiquetas de variable y de valor
#'
#' @param datos Datos a etiquetar.
#' @param etiquetas Una especificación (`cfg$ETIQUETAS` o
#'   `cfg$ETIQUETAS_SEC`): lista con `variables` y `valores`.
#' @return `datos` con las etiquetas aplicadas.
etiquetar <- function(datos, etiquetas) {
    datos <- purrr::reduce2(
        unname(etiquetas$variables),
        names(etiquetas$variables),
        \(data, var, etiqueta) {
            data |>
                dplyr::mutate(
                    "{var}" := sjlabelled::set_label(
                        .data[[var]],
                        label = etiqueta
                    )
                )
        },
        .init = datos
    )

    purrr::reduce2(
        names(etiquetas$valores),
        etiquetas$valores,
        \(data, var, valores) {
            data |>
                dplyr::mutate(
                    "{var}" := sjlabelled::set_labels(
                        .data[[var]],
                        labels = valores
                    )
                )
        },
        .init = datos
    )
}
