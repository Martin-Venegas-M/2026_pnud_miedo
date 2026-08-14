# Diccionario de variables
#
# Responde tres preguntas que de otro modo habría que contestar leyendo código:
# qué variables existen, cuáles se usan en el análisis, y cómo se construye cada
# una a partir de las otras.
#
# Es un target y no una tabla mantenida a mano porque se deriva de las
# declaraciones del pipeline y de las etiquetas de la base: así no puede
# desincronizarse de lo que el código hace realmente.


#' Categorías de una columna, como texto legible
#'
#' @param col Columna, posiblemente etiquetada.
#' @param max_cats Cuántas categorías listar antes de truncar.
#' @return Un string `"1 = Muy inseguro; 2 = Inseguro; ..."`, o `""` si la
#'   columna no tiene etiquetas de valor.
categorias_de <- function(col, max_cats = 12) {
    labs <- attr(col, "labels")

    if (is.null(labs)) {
        if (is.factor(col)) {
            return(paste(levels(col), collapse = "; "))
        }
        return("")
    }

    texto <- paste0(unname(labs), " = ", names(labs))
    if (length(texto) > max_cats) {
        texto <- c(texto[seq_len(max_cats)], "...")
    }
    paste(texto, collapse = "; ")
}

#' Diccionario completo de variables
#'
#' Una fila por variable, con su familia, su etiqueta, sus categorías, de
#' qué se construye y qué papel cumple en el análisis.
#'
#' @param datos_sel `datos_seleccionados` (originales, ya renombradas).
#' @param datos_fin `datos_finales` (todo lo construido).
#' @param mapeo `mapeo_nombres`.
#' @param spec `cfg$INDICES`.
#' @param vars_modelo `cfg$VARS_MODELO`.
#' @param vars_sec `cfg$VARS_SEC`.
#' @param n_clases `cfg$N_CLASES`.
#' @param codigos `cfg$CODIGOS_COMGEN`.
#' @param secundarias `cfg$SECUNDARIAS`.
#' @return Un tibble con una fila por variable.
construir_metadata <- function(
    datos_sel,
    datos_fin,
    mapeo,
    spec,
    vars_modelo,
    vars_sec,
    n_clases,
    codigos,
    secundarias
) {
    original_de <- stats::setNames(mapeo$original, mapeo$nuestro)

    #* De qué índice es insumo cada variable original. Se invierte cfg$INDICES
    #* en vez de escribirlo a mano: si el spec cambia, esto cambia con él.
    insumo_de <- purrr::imap(spec, function(cols, indice) {
        #* La clave de `spec` no siempre es una columna: los grupos de ítems que
        #* no dejan un `_pct` en los datos alimentan directo a su variable
        #* categorizada. Sin esto, la tabla de originales mandaría a buscar una
        #* columna que el pipeline ya no produce.
        destino <- if (indice %in% names(datos_fin)) {
            indice
        } else if (paste0(indice, "_cat") %in% names(datos_fin)) {
            paste0(indice, "_cat")
        } else {
            indice
        }
        tibble::tibble(variable = unlist(cols), alimenta = destino)
    }) |>
        purrr::list_rbind() |>
        dplyr::summarise(
            alimenta = paste(sort(unique(alimenta)), collapse = ", "),
            .by = variable
        )

    sec <- secundarias
    origen_sec <- purrr::imap(sec, function(prefijo, creada) {
        cols <- grep(paste0("^", prefijo), names(datos_sel), value = TRUE)
        if (length(cols) == 0) {
            rlang::abort(paste0(
                "cfg$SECUNDARIAS nombra un origen que no existe: '", prefijo, "'."
            ))
        }
        tibble::tibble(variable = cols, alimenta = creada)
    }) |>
        purrr::list_rbind() |>
        dplyr::summarise(
            alimenta = paste(sort(unique(alimenta)), collapse = ", "),
            .by = variable
        )

    #* Algunas secundarias entran al análisis tal como vienen, sin construir
    #* nada (sexo, NSE, victimización). Sin esta línea aparecían como "No se
    #* usa", que es justo la ambigüedad que este diccionario tiene que evitar.
    directas <- tibble::tibble(
        variable = intersect(vars_sec, names(datos_sel)),
        alimenta = "Se usa directamente como variable secundaria"
    )

    #* Las columnas de código especial de comgen no están en `cfg$INDICES`, así
    #* que caían en "No se usa". Era falso para `_ns` y `_nr`, que sí se leen, y
    #* engañoso para `_na`, cuya exclusión es la decisión que originó el repo.
    marcas_comgen <- purrr::imap(
        codigos,
        function(marcas, destino) {
            tibble::tibble(
                variable = unname(marcas[c("ns", "nr")]),
                alimenta = paste0(
                    "Marca de no respuesta: fija 88/99 en ",
                    destino
                )
            )
        }
    ) |>
        purrr::list_rbind()

    ninguna_comgen <- tibble::tibble(
        variable = purrr::map_chr(codigos, \(m) unname(m[["na"]])),
        alimenta = paste(
            "Excluida de la batería a propósito: quien la marca tiene",
            "todas las medidas en 0, así que el conteo le da 0 sin leer esta",
            "columna"
        )
    )

    uso_original <- dplyr::bind_rows(
        insumo_de,
        origen_sec,
        directas,
        marcas_comgen,
        ninguna_comgen
    ) |>
        dplyr::summarise(
            alimenta = paste(alimenta, collapse = ", "),
            .by = variable
        )

    # --- Variables originales ------------------------------------------------
    #* Se excluyen las de diseño muestral y los identificadores: no son
    #* respuestas de la encuesta y confunden más de lo que aportan acá.
    tecnicas <- c(
        "rph_id",
        "idhogar",
        "conglomerado",
        "var_strat",
        "fact_pers_reg",
        "fact_hog_reg"
    )
    cols_orig <- setdiff(names(datos_sel), tecnicas)

    originales <- tibble::tibble(
        familia = "Original",
        variable = cols_orig,
        original = unname(original_de[cols_orig]),
        etiqueta = purrr::map_chr(
            datos_sel[cols_orig],
            \(c) attr(c, "label") %||% ""
        ),
        categorias = purrr::map_chr(datos_sel[cols_orig], categorias_de)
    ) |>
        dplyr::left_join(uso_original, by = "variable") |>
        dplyr::mutate(
            construida_desde = NA_character_,
            uso = dplyr::coalesce(alimenta, "No se usa"),
            .keep = "unused"
        )

    # --- Índices continuos ---------------------------------------------------
    #* `spec` nombra grupos de ítems, no necesariamente columnas: los dos de
    #* comgen se categorizan contando directo sobre la batería y no dejan un
    #* `_pct` en los datos. Se cruza con las columnas que existen para que la
    #* lista se corrija sola si otro índice sigue el mismo camino.
    indices <- intersect(
        names(spec)[grepl("_pct$", names(spec))],
        names(datos_fin)
    )

    if (length(indices) == 0) {
        rlang::abort("No quedó ningún índice continuo en los datos.")
    }
    fuente_pct <- tibble::tibble(
        familia = "Fuente: índice",
        variable = indices,
        original = NA_character_,
        etiqueta = purrr::map_chr(
            datos_fin[indices],
            \(c) attr(c, "label") %||% ""
        ),
        categorias = "Continua, 0 a 100",
        construida_desde = purrr::map_chr(
            indices,
            \(i) paste(unlist(spec[[i]]), collapse = ", ")
        ),
        uso = "Insumo de su versión categorizada"
    )

    # --- Categorizadas y otras variables fuente ------------------------------
    fuente_cat <- tibble::tibble(
        familia = "Fuente: categorizada",
        variable = vars_modelo,
        original = NA_character_,
        etiqueta = purrr::map_chr(
            datos_fin[vars_modelo],
            \(c) attr(c, "label") %||% ""
        ),
        categorias = purrr::map_chr(datos_fin[vars_modelo], categorias_de),
        #* Una `_cat` se construye desde su índice `_pct` solo si ese índice
        #* existe. Los dos de comgen se cuentan directo sobre la batería, así
        #* que apuntan a los ítems: decir `comgen_per` mandaría a buscar una
        #* columna que el pipeline ya no produce.
        construida_desde = purrr::map_chr(
            vars_modelo,
            function(v) {
                pct <- sub("_cat$", "", v)
                if (pct != v && pct %in% names(datos_fin)) {
                    pct
                } else {
                    paste(unlist(spec[[pct]]), collapse = ", ")
                }
            }
        ),
        uso = "Entra al modelo (MCA)"
    )

    # --- Clusters ------------------------------------------------------------
    vars_clust <- paste0("clusters_", sort(n_clases))
    clusters <- tibble::tibble(
        familia = "Cluster",
        variable = vars_clust,
        original = NA_character_,
        etiqueta = paste0("Solución de ", sort(n_clases), " grupos"),
        categorias = purrr::map_chr(datos_fin[vars_clust], categorias_de),
        construida_desde = paste(vars_modelo, collapse = ", "),
        uso = "Resultado del modelo"
    )

    # --- Secundarias ---------------------------------------------------------
    secundarias <- tibble::tibble(
        familia = "Secundaria",
        variable = vars_sec,
        original = unname(original_de[vars_sec]),
        etiqueta = purrr::map_chr(
            datos_fin[vars_sec],
            \(c) attr(c, "label") %||% ""
        ),
        categorias = purrr::map_chr(datos_fin[vars_sec], categorias_de),
        construida_desde = purrr::map_chr(
            vars_sec,
            \(v) {
                if (v %in% names(sec)) {
                    paste(
                        grep(
                            paste0("^", sec[[v]]),
                            names(datos_sel),
                            value = TRUE
                        ),
                        collapse = ", "
                    )
                } else {
                    "Directa de la ENUSC, sin transformar"
                }
            }
        ),
        uso = "Describe los grupos, no entra al modelo"
    )

    dplyr::bind_rows(
        originales,
        fuente_pct,
        fuente_cat,
        clusters,
        secundarias
    ) |>
        dplyr::relocate(
            familia,
            variable,
            original,
            etiqueta,
            categorias,
            construida_desde,
            uso
        )
}
