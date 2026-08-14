#' Convertir los índices `_pct` en categorías
#'
#' Reemplaza `2_recode.R:169`. Acá se resolvió D2.
#'
#' @section Qué reemplaza y por qué:
#' Hasta agosto de 2026 esto era `ntile(., 3)`, que fuerza tres grupos del mismo
#' tamaño y desempata **por orden de fila**. Cuando un valor del índice reúne
#' más gente de la que cabe en un tercil, el corte lo parte: personas con la
#' misma respuesta caen en categorías distintas, y reordenar la base cambia el
#' resultado.
#'
#' El caso extremo era `emper_casa_pct`: tres cuartos de la muestra responden
#' 0%, así que ese único valor ocupaba más de dos terciles y desbordaba al
#' tercero. 5.088 personas que declararon sentirse seguras en su casa quedaban
#' etiquetadas "Alta inseguridad en la casa".
#'
#' @section El criterio que lo reemplaza:
#' Cortar por lo que la variable significa, no por la forma de su distribución,
#' con el **cero siempre como categoría propia**. Eso último continúa a D1: si
#' quien respondió "ninguna medida" se mezcla con quien tiene una o dos, el
#' rescate de D1 queda a medias.
#'
#' Los cuatro índices no están construidos igual, así que hay dos métodos:
#'
#' - `"valor"`: el índice tiene tres valores posibles (0, 50, 100) porque se
#'   construye con dos ítems. Se usa el valor como categoría.
#' - `"porcentaje"`: los ítems admiten el código 85, así que el denominador
#'   cambia por persona y un conteo no sería comparable. Se corta sobre el
#'   porcentaje.
#'
#' En los dos casos el insumo es la columna `_pct`, y el porcentaje está
#' haciendo trabajo real: normaliza sobre las situaciones que le aplican a cada
#' persona.
#'
#' @section Lo que ya no hace:
#' Hasta agosto de 2026 había un tercer método, `"conteo"`, para las dos
#' variables de `comgen`. Esa rama no tocaba ningún índice: leía la batería de
#' ítems y obligaba a esta función a recibir las columnas fuente y a validar de
#' forma distinta según el método. Se mudó a [categorizar_comgen()].
#'
#' @section La aserción:
#' Ningún valor del insumo puede caer en más de una categoría. Es el invariante
#' que este cambio establece, y verificarlo acá deja el bug de los terciles
#' estructuralmente imposible de reintroducir.
#'
#' @param datos Datos con las columnas `_pct`.
#' @param spec Lista `variable -> list(metodo, cortes)`, normalmente
#'   `cfg$CORTES`. Las entradas de método `"conteo"` se ignoran: las procesa
#'   [categorizar_comgen()].
#' @return `datos` con una columna `{col}_cat` por cada índice.
categorizar_indices <- function(datos, spec) {
    spec <- spec[vapply(spec, \(s) s$metodo != "conteo", logical(1))]

    faltan <- setdiff(names(spec), names(datos))
    if (length(faltan) > 0) {
        stop(
            "categorizar_indices(): el spec nombra índices que no existen: ",
            paste(faltan, collapse = ", ")
        )
    }

    for (v in names(spec)) {
        s <- spec[[v]]
        x <- as.numeric(haven::zap_labels(datos[[v]]))

        cats <- switch(
            s$metodo,
            valor = as.integer(factor(x, levels = s$cortes)),
            porcentaje = cut(
                x,
                breaks = c(-1, s$cortes, 100),
                labels = FALSE
            ),
            stop("categorizar_indices(): método desconocido '", s$metodo, "'")
        )

        #* Un valor del índice no puede quedar repartido entre categorías. Si
        #* esto falla, el corte volvió a depender de la distribución.
        reparto <- tapply(cats, x, \(g) length(unique(g[!is.na(g)])))
        if (any(reparto > 1, na.rm = TRUE)) {
            malos <- names(reparto)[which(reparto > 1)]
            stop(
                "categorizar_indices(): en '",
                v,
                "' el corte parte valores idénticos entre categorías: ",
                paste(malos, collapse = ", ")
            )
        }

        datos[[paste0(v, "_cat")]] <- cats
    }

    datos
}
