#' Impedir que la no respuesta se lea como respuesta sustantiva
#'
#' Cuando alguien responde "no aplica", "no sabe" o "no responde" a **todos** los
#' ítems de una batería, el índice de porcentaje le da 0%: el denominador cuenta
#' esos ítems y ninguno es un éxito. Con 0% cae en la primera categoría, que en
#' estas variables significa "sin inseguridad" o "no modificó prácticas". Es una
#' respuesta sustantiva que esa persona nunca dio.
#'
#' Este paso lo revierte: si todos los ítems fuente comparten el mismo código
#' especial, ese código se reimputa en la variable `_cat`.
#'
#' @section Cuánta gente mueve:
#' En la corrida de agosto de 2026, unas **1.300 personas** en las cuatro
#' variables de índice, de las cuales unas **25 salían de la categoría 1** hacia
#' un código de no respuesta; el resto llegaba desde `NA`. Los movimientos
#' quedan en el log de este paso, que es el único lugar donde se ven: en las
#' marginales finales solo se vería el resultado.
#'
#' @section Por qué sigue siendo un paso aparte:
#' Es la misma pregunta que resolvió D1 y merece el mismo tratamiento: la
#' distinción entre "respondió que no" y "no respondió" tiene que ser visible en
#' el registro, no solo correcta en el resultado. Fundirlo dentro de
#' [categorizar_indices()] daría el mismo dato final y borraría la transición.
#'
#' Tampoco lleva un argumento para desactivarlo. Con `FALSE` el pipeline
#' produciría categorías falsas en silencio, así que no hay un caso de uso
#' legítimo para esa opción.
#'
#' @section Lo que ya no hace:
#' Hasta agosto de 2026 acá también se estampaban los códigos `88`/`99` de
#' `comgen` desde sus columnas `_ns`/`_nr`. Eso se mudó a [categorizar_comgen()]:
#' son códigos especiales de esa batería, y quien construye la variable se hace
#' cargo de ellos.
#'
#' @param datos Datos con las columnas `_cat` ya construidas.
#' @param spec `cfg$INDICES`: ítems fuente por batería.
#' @param cortes `cfg$CORTES`, para saber cuáles son variables de índice: las de
#'   método `"conteo"` se saltan, porque sus ítems son columnas dummy `0`/`1`
#'   que nunca valen `85`/`88`/`99`.
#' @return `datos` con los códigos especiales reimputados en las `_cat`.
rescatar_no_respuesta <- function(datos, spec, cortes) {
    indices <- names(cortes)[
        vapply(cortes, \(s) s$metodo != "conteo", logical(1))
    ]

    purrr::reduce(
        indices,
        \(data, v) {
            items <- spec[[v]]
            data |>
                dplyr::mutate(
                    "{v}_cat" := dplyr::case_when(
                        dplyr::if_all(dplyr::all_of(items), ~ . == 85) ~ 85,
                        dplyr::if_all(dplyr::all_of(items), ~ . == 88) ~ 88,
                        dplyr::if_all(dplyr::all_of(items), ~ . == 99) ~ 99,
                        TRUE ~ .data[[paste0(v, "_cat")]]
                    )
                )
        },
        .init = datos
    )
}

