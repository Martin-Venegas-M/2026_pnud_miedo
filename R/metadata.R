# Diccionario de variables (PLAN.md F5.5)
#
# Responde tres preguntas que hasta ahora había que contestar leyendo código:
# qué variables existen, cuáles se usan en el análisis, y cómo se construye cada
# una a partir de las otras.
#
# Es un target y no un chunk de la página porque es un artefacto del pipeline:
# se deriva de `spec_indices` y de las etiquetas de la base, así que no puede
# desincronizarse de lo que el código hace realmente. Reemplaza al
# `metadata_recode.xlsx` del repo viejo, que se generaba con un `separate()`
# frágil y había que mantener a mano (F5.2, Q5).

#' Origen de las variables secundarias
#'
#' `spec_indices` cubre la lineage de las variables fuente, pero las secundarias
#' se construyen en `R/vars_secundarias.R` sin pasar por un spec. Se declara acá
#' y se verifica contra los datos: si una columna deja de existir, falla.
#'
#' @return Lista `variable_creada -> columnas de origen`.
spec_secundarias <- function() {
    list(
        desordenes_ind = "p_desordenes_",
        incivilidades_ind = "p_incivilidades_",
        info_exp_personal = "p_fuente_info_",
        info_otras_personas = "p_fuente_info_",
        info_rrss = "p_fuente_info_",
        info_prensa = "p_fuente_info_",
        info_tv = "p_fuente_info_",
        rph_nivel_rec = "rph_nivel",
        rph_edad_rec = "rph_edad",
        enc_region_rec = "enc_region"
    )
}

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
#' Una fila por variable, con su familia (§4.0), su etiqueta, sus categorías, de
#' qué se construye y qué papel cumple en el análisis.
#'
#' @param datos_sel `datos_seleccionados` (originales, ya renombradas).
#' @param datos_fin `datos_finales` (todo lo construido).
#' @param mapeo `mapeo_nombres`.
#' @param spec `spec_indices`.
#' @param vars_modelo `cfg$VARS_REC_TERCIL`.
#' @param vars_sec `cfg$VARS_SEC`.
#' @param n_clases `cfg$N_CLASES`.
#' @return Un tibble con una fila por variable.
construir_metadata <- function(
    datos_sel,
    datos_fin,
    mapeo,
    spec,
    vars_modelo,
    vars_sec,
    n_clases
) {
    original_de <- stats::setNames(mapeo$original, mapeo$nuestro)

    #* De qué índice es insumo cada variable original. Se invierte spec_indices
    #* en vez de escribirlo a mano: si el spec cambia, esto cambia con él.
    insumo_de <- purrr::imap(spec, function(cols, indice) {
        tibble::tibble(variable = unlist(cols), alimenta = indice)
    }) |>
        purrr::list_rbind() |>
        dplyr::summarise(
            alimenta = paste(sort(unique(alimenta)), collapse = ", "),
            .by = variable
        )

    sec <- spec_secundarias()
    origen_sec <- purrr::imap(sec, function(prefijo, creada) {
        cols <- grep(paste0("^", prefijo), names(datos_sel), value = TRUE)
        stopifnot(
            "spec_secundarias() nombra un origen que no existe en los datos" = length(
                cols
            ) >
                0
        )
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

    uso_original <- dplyr::bind_rows(insumo_de, origen_sec, directas) |>
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
        etiqueta = vapply(
            datos_sel[cols_orig],
            \(c) attr(c, "label") %||% "",
            character(1)
        ),
        categorias = vapply(datos_sel[cols_orig], categorias_de, character(1))
    ) |>
        dplyr::left_join(uso_original, by = "variable") |>
        dplyr::mutate(
            construida_desde = NA_character_,
            uso = dplyr::coalesce(alimenta, "No se usa"),
            .keep = "unused"
        )

    # --- Índices continuos ---------------------------------------------------
    indices <- names(spec)[grepl("_pct$", names(spec))]
    fuente_pct <- tibble::tibble(
        familia = "Fuente: índice",
        variable = indices,
        original = NA_character_,
        etiqueta = vapply(
            datos_fin[indices],
            \(c) attr(c, "label") %||% "",
            character(1)
        ),
        categorias = "Continua, 0 a 100",
        construida_desde = vapply(
            indices,
            \(i) paste(unlist(spec[[i]]), collapse = ", "),
            character(1)
        ),
        uso = "Insumo de su versión categorizada"
    )

    # --- Categorizadas y otras variables fuente ------------------------------
    fuente_cat <- tibble::tibble(
        familia = "Fuente: categorizada",
        variable = vars_modelo,
        original = NA_character_,
        etiqueta = vapply(
            datos_fin[vars_modelo],
            \(c) attr(c, "label") %||% "",
            character(1)
        ),
        categorias = vapply(datos_fin[vars_modelo], categorias_de, character(1)),
        construida_desde = dplyr::case_when(
            grepl("_rec_tercil$", vars_modelo) ~ sub("_rec_tercil$", "", vars_modelo),
            TRUE ~ vapply(
                vars_modelo,
                \(v) paste(unlist(spec[[v]]), collapse = ", "),
                character(1)
            )
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
        categorias = vapply(datos_fin[vars_clust], categorias_de, character(1)),
        construida_desde = paste(vars_modelo, collapse = ", "),
        uso = "Resultado del modelo"
    )

    # --- Secundarias ---------------------------------------------------------
    secundarias <- tibble::tibble(
        familia = "Secundaria",
        variable = vars_sec,
        original = unname(original_de[vars_sec]),
        etiqueta = vapply(
            datos_fin[vars_sec],
            \(c) attr(c, "label") %||% "",
            character(1)
        ),
        categorias = vapply(datos_fin[vars_sec], categorias_de, character(1)),
        construida_desde = vapply(
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
            },
            character(1)
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
