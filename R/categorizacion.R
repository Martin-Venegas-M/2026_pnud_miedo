#' Convertir los índices `_pct` en terciles
#'
#' Reemplaza `2_recode.R:169`. Vive acá D2: `ntile()` fuerza grupos de igual
#' tamaño y desempata por orden de fila, así que personas con la misma
#' respuesta pueden caer en terciles distintos. No se corrige en esta fase
#' (ver F1.0).
#'
#' @param datos Datos con las columnas `_pct`.
#' @param metodo Método de corte. Solo `"ntile"` está implementado en esta
#'   fase; el parámetro existe para que la Fase 4 pueda comparar variantes de
#'   D2 cambiando un argumento, no copiando esta función.
#' @return `datos` con una columna `{col}_rec_tercil` por cada columna que
#'   termina en `_pct`.
categorizar_indices <- function(datos, metodo = "ntile") {
    if (metodo != "ntile") {
        stop(
            "categorizar_indices(): método '",
            metodo,
            "' no implementado en esta fase"
        )
    }

    datos |>
        dplyr::mutate(dplyr::across(
            dplyr::ends_with("_pct"),
            ~ dplyr::ntile(., 3),
            .names = "{.col}_rec_tercil"
        ))
}
