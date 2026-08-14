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
#' Como los seis índices no están construidos igual, hay tres métodos, y no
#' todos parten del mismo insumo:
#'
#' - `"valor"`: el índice tiene tres valores posibles (0, 50, 100) porque se
#'   construye con dos ítems. Se usa el valor como categoría. **Insumo: la
#'   columna `_pct`.**
#' - `"porcentaje"`: los ítems admiten el código 85, así que el denominador
#'   cambia por persona y un conteo no sería comparable. Se corta sobre el
#'   porcentaje. **Insumo: la columna `_pct`.**
#' - `"conteo"`: ningún ítem de la batería admite 85, así que el denominador es
#'   constante y lo interpretable es el número de medidas. Se cuenta directo
#'   sobre la batería. **Insumo: los ítems, vía `spec_items`.**
#'
#' @section Por qué `"conteo"` no pasa por el índice:
#' Hasta agosto de 2026 los dos índices de `comgen` se construían como
#' porcentaje y acá se revertían con `round(x * n_items / 100)`. Como el
#' denominador es constante, la vuelta era exacta, pero el porcentaje no se
#' usaba para nada más: no entra al modelo y no se publica. Se verificó que
#' contar directo sobre la batería da la **misma categoría en las 55.796 filas**,
#' incluidos los códigos 88 y 99. El índice intermedio se retiró.
#'
#' Los índices de método `"valor"` y `"porcentaje"` **sí conservan su `_pct`**:
#' ahí el denominador varía (hay ítems con código 85) y el porcentaje normaliza
#' sobre las situaciones que le aplican a cada persona. Un conteo no sería
#' comparable entre dos personas con distinto número de situaciones aplicables.
#'
#' @section La aserción:
#' Ningún valor del insumo puede caer en más de una categoría. Es el invariante
#' que este cambio establece, y verificarlo acá deja el bug de los terciles
#' estructuralmente imposible de reintroducir.
#'
#' @param datos Datos con las columnas `_pct` y las baterías de ítems.
#' @param spec Lista `variable -> list(metodo, cortes)`, normalmente
#'   `cfg$CORTES`.
#' @param spec_items Lista `variable -> vector de columnas de la batería`,
#'   normalmente `cfg$INDICES`. Solo se usa para el método `"conteo"`.
#' @return `datos` con una columna `{col}_cat` por cada índice.
categorizar_indices <- function(datos, spec, spec_items) {
    #* La validación es consciente del método: para "conteo" la clave del spec
    #* nombra un grupo de ítems y no una columna del data frame.
    desde_pct <- names(spec)[
        vapply(spec, \(s) s$metodo != "conteo", logical(1))
    ]
    desde_items <- setdiff(names(spec), desde_pct)

    faltan <- c(
        setdiff(desde_pct, names(datos)),
        setdiff(unlist(spec_items[desde_items]), names(datos))
    )
    if (length(faltan) > 0) {
        stop(
            "categorizar_indices(): el spec nombra columnas que no existen: ",
            paste(faltan, collapse = ", ")
        )
    }

    for (v in names(spec)) {
        s <- spec[[v]]

        #* `x` es lo que se corta y también sobre lo que se verifica el
        #* invariante, así que tiene que ser el insumo real de cada método.
        x <- if (s$metodo == "conteo") {
            items <- as.matrix(as.data.frame(lapply(
                datos[spec_items[[v]]],
                \(col) as.numeric(haven::zap_labels(col))
            )))
            rowSums(items == 1)
        } else {
            as.numeric(haven::zap_labels(datos[[v]]))
        }

        cats <- switch(
            s$metodo,
            valor = as.integer(factor(x, levels = s$cortes)),
            conteo = cut(x, breaks = c(-1, s$cortes, Inf), labels = FALSE),
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
