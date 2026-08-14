#' Convertir los índices `_pct` en categorías
#'
#' El MCA trabaja con variables categóricas, así que cada índice continuo tiene
#' que volverse un conjunto de categorías. El criterio es cortar **por lo que la
#' variable significa**, no por la forma de su distribución.
#'
#' Hay dos métodos, según cómo esté construido el índice:
#'
#' - `"valor"`: se construye con dos ítems, así que solo puede valer 0, 50 o
#'   100. Se usa el valor como categoría.
#' - `"porcentaje"`: sus ítems admiten el código 85 ("no aplica"), así que el
#'   denominador cambia de persona a persona. Se corta sobre el porcentaje.
#'
#' Las entradas de método `"conteo"` se ignoran acá: no tienen índice y las
#' procesa [categorizar_comgen()].
#'
#' @details
#' **El cero es siempre una categoría propia.** Quien responde "ninguna medida"
#' o "ningún lugar inseguro" está dando una respuesta sustantiva, distinta de
#' quien responde "una o dos". Mezclarlos en una categoría "baja" borraría esa
#' distinción dentro del modelo.
#'
#' **La aserción del final es el invariante de esta función.** Ningún valor del
#' índice puede quedar repartido entre dos categorías. Un corte por cuantiles no
#' lo cumple: cuando un valor reúne más gente de la que cabe en un tramo, lo
#' parte, y personas que respondieron exactamente lo mismo caen en categorías
#' distintas. En `emper_casa_pct` tres cuartos de la muestra responden 0%, así
#' que ese único valor desbordaba cualquier tercil. Verificarlo acá hace ese
#' problema estructuralmente imposible.
#'
#' @param datos Datos con las columnas `_pct`.
#' @param spec Lista `variable -> list(metodo, cortes)`, normalmente
#'   `cfg$CORTES`.
#' @return `datos` con una columna `{col}_cat` por cada índice.
categorizar_indices <- function(datos, spec) {
    spec <- spec[purrr::map_lgl(spec, \(s) s$metodo != "conteo")]

    faltan <- setdiff(names(spec), names(datos))
    if (length(faltan) > 0) {
        rlang::abort(c(
            "El spec nombra índices que no existen en los datos.",
            x = paste("Faltan:", paste(faltan, collapse = ", "))
        ))
    }

    purrr::reduce(
        names(spec),
        function(data, v) {
            s <- spec[[v]]
            x <- as.numeric(haven::zap_labels(data[[v]]))

            cats <- switch(
                s$metodo,
                valor = as.integer(factor(x, levels = s$cortes)),
                porcentaje = cut(
                    x,
                    breaks = c(-1, s$cortes, 100),
                    labels = FALSE
                ),
                rlang::abort(paste0("Método de corte desconocido: '", s$metodo, "'"))
            )

            #* Un valor del índice no puede quedar repartido entre categorías. Si
            #* esto falla, el corte volvió a depender de la distribución.
            reparto <- purrr::map_int(
                split(cats, x),
                \(g) length(unique(g[!is.na(g)]))
            )
            if (any(reparto > 1)) {
                rlang::abort(c(
                    paste0("En '", v, "' el corte parte valores idénticos entre categorías."),
                    x = paste(
                        "Valores repartidos:",
                        paste(names(reparto)[reparto > 1], collapse = ", ")
                    ),
                    i = "El corte volvió a depender de la distribución y no del significado."
                ))
            }

            data[[paste0(v, "_cat")]] <- cats
            data
        },
        .init = datos
    )
}
