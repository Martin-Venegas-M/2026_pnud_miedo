#' Construir el objeto de diseño muestral
#'
#' PLAN.md F5.3, "Trampa: el objeto de diseño muestral": no existía en el DAG
#' hasta acá. Es donde vivía el typo `stata = ` del repo viejo — acá se usa
#' `strata =`, y se verifica antes que las tres columnas existan, para que un
#' nombre mal escrito falle con un mensaje claro en vez de dejar el diseño sin
#' estratificar en silencio.
#'
#' @param datos Datos finales (`datos_finales`).
#' @param ids,strata,weights Nombres de columna, como string (`cfg$SVY_IDS`,
#'   `cfg$SVY_STRATA`, `cfg$SVY_WEIGHTS`).
#' @return Un objeto `srvyr::as_survey_design()`.
construir_diseno_muestral <- function(datos, ids, strata, weights) {
    faltantes <- setdiff(c(ids, strata, weights), names(datos))
    if (length(faltantes) > 0) {
        stop(
            "construir_diseno_muestral(): columnas de diseño muestral no encontradas en datos_finales: ",
            paste(faltantes, collapse = ", ")
        )
    }

    datos |>
        srvyr::as_survey_design(
            ids = !!rlang::sym(ids),
            strata = !!rlang::sym(strata),
            weights = !!rlang::sym(weights)
        )
}

#' Mapeo de nombres: variables originales -> nuestro nombre
#'
#' PLAN.md §4.0: "el mapeo original -> nuestro nombre... es derivable del
#' código y no hay que mantenerlo a mano." Reproduce la misma selección que
#' `seleccionar_variables()` (`R/seleccion.R`) solo para capturar, en el mismo
#' orden, el nombre original de cada columna antes de sus `rename_with()`. Si
#' la selección de `seleccionar_variables()` cambia, cambiar acá también — el
#' `stopifnot` falla si se desincronizan en cantidad de columnas.
#'
#' @param datos_muestra Datos post-Kish, pre-selección (`datos_muestra`).
#' @param datos_seleccionados Datos ya seleccionados y renombrados
#'   (`datos_seleccionados`).
#' @return Un tibble `original | nuestro`.
construir_mapeo_nombres <- function(datos_muestra, datos_seleccionados) {
    originales <- datos_muestra |>
        dplyr::select(
            rph_ID,
            idhogar,
            Conglomerado,
            VarStrat,
            Fact_Pers_Reg,
            Fact_Hog_Reg,
            dplyr::starts_with("P_INSEG"),
            dplyr::starts_with("P_EXPOS_DELITO"),
            dplyr::starts_with("P_DELITO_PRONOSTICO"),
            dplyr::starts_with("P_MOD_ACTIVIDADES"),
            dplyr::starts_with("COSTOS_MEDIDAS"),
            dplyr::starts_with("MEDIDAS"),
            dplyr::starts_with("VECINOS_MEDIDAS"),
            dplyr::starts_with("rph"),
            enc_region,
            VH_DC,
            VP_DC,
            VH_DV,
            VP_DV,
            dplyr::starts_with("P_FUENTE_INFO_"),
            dplyr::starts_with("P_DESORDENES_"),
            dplyr::starts_with("P_INCIVILIDADES_")
        ) |>
        names()

    nuestro <- names(datos_seleccionados)

    stopifnot(
        "construir_mapeo_nombres() desincronizado de seleccionar_variables(): distinto número de columnas" = length(
            originales
        ) ==
            length(nuestro)
    )

    tibble::tibble(original = originales, nuestro = nuestro)
}

#' Tabla 1 — Univariados de variables originales, por dimensión
#'
#' PLAN.md F5.3. Corre sobre `datos_seleccionados` (originales, renombradas,
#' sin recodificar) con `spec_patrones` para separar pregunta de ítem en la
#' etiqueta. La dimensión `pergen` no entra: se descartó (§4.0), a diferencia
#' del reporte del repo viejo que todavía la incluía.
#'
#' No depende de D2 — son valores originales, la categorización no los toca.
#'
#' @param datos `datos_seleccionados`.
#' @param spec_patrones `spec_patrones`.
#' @return Un tibble largo, una fila por categoría de cada variable.
tabla_variables_originales <- function(datos, spec_patrones) {
    dimensiones <- c("emper", "perper", "comper", "comgen")

    purrr::map(dimensiones, function(dim) {
        vars <- datos |>
            dplyr::select(dplyr::starts_with(paste0(dim, "_"))) |>
            names()
        patron <- spec_patrones[[dim]]

        purrr::map(vars, function(v) {
            tab_frq1(
                data = datos,
                var = !!rlang::sym(v),
                pattern_verbose = patron$sep %||% "\\? ",
                extraer_verbose = patron$extraer
            )
        }) |>
            purrr::list_rbind() |>
            dplyr::mutate(dimension = dim) |>
            dplyr::relocate(dimension)
    }) |>
        purrr::list_rbind()
}

#' Tabla 2 — Univariados de variables fuente
#'
#' PLAN.md F5.3. Los índices `_pct` continuos y sus versiones categorizadas
#' (`cfg$VARS_REC_TERCIL`, que además de las categorizadas incluye
#' `perper_delito` y `comper_gasto`). Corre sobre `datos_finales`.
#'
#' Depende de D1 y D3 (ya aplicadas) y de D2 (abierta) para la parte
#' categorizada — no para los `_pct` continuos, que D2 no toca.
#'
#' @param datos `datos_finales`.
#' @param vars_continuas Los seis índices `_pct` sin categorizar.
#' @param vars_categorizadas `cfg$VARS_REC_TERCIL`.
#' @return Un tibble largo.
tabla_variables_fuente <- function(datos, vars_continuas, vars_categorizadas) {
    purrr::map(c(vars_continuas, vars_categorizadas), function(v) {
        tab_frq1(data = datos, var = !!rlang::sym(v), verbose = FALSE)
    }) |>
        purrr::list_rbind()
}

#' Tabla 3 — Univariados de variables secundarias
#'
#' PLAN.md F5.3. `cfg$VARS_SEC` sobre `datos_finales`. No depende de D2;
#' `desordenes_ind_rec`/`incivilidades_ind_rec` sí dependen de D5 (abierta).
#'
#' @param datos `datos_finales`.
#' @param vars_sec `cfg$VARS_SEC`.
#' @return Un tibble largo.
tabla_variables_secundarias <- function(datos, vars_sec) {
    purrr::map(vars_sec, function(v) {
        tab_frq1(data = datos, var = !!rlang::sym(v), verbose = FALSE)
    }) |>
        purrr::list_rbind()
}

#' Tabla 4 — Distribución de las soluciones de cluster
#'
#' PLAN.md F5.3. Depende de D2 (la categorización que alimenta el MCA).
#'
#' @param datos `datos_finales`.
#' @param n_clases `cfg$N_CLASES`.
#' @return Un tibble largo.
tabla_clusters <- function(datos, n_clases) {
    purrr::map(paste0("clusters_", n_clases), function(v) {
        tab_frq1(data = datos, var = !!rlang::sym(v), verbose = FALSE)
    }) |>
        purrr::list_rbind()
}

#' Tabla 5 — Cruces de variables fuente y secundarias por cluster
#'
#' PLAN.md F5.3. Usa `tab_var_clust()` (F5.2, Q2) con `invert = FALSE`: % de
#' cada categoría de la variable dentro de cada cluster — el perfil pedido.
#' La dirección invertida no se pide.
#'
#' Depende de D2 (categorización, MCA, clusters) y de D5 en la porción de
#' variables secundarias.
#'
#' @param svy Diseño muestral (`construir_diseno_muestral()`).
#' @param clust_var `cfg$CLUSTER_A_SACAR`.
#' @param vars_fuente `cfg$VARS_REC_TERCIL`.
#' @param vars_sec `cfg$VARS_SEC`.
#' @return Un tibble largo, con una columna `grupo_variable` (`"fuente"` o
#'   `"secundaria"`).
#'
#' @details
#' `tab_var_clust()` devuelve una lista con un tibble por variable, cada uno
#' con su propia columna `val` (el código crudo, `haven_labelled` con las
#' etiquetas de ESA variable). Antes de unirlos en una sola tabla larga, `val`
#' se pasa a texto: un `1` no significa lo mismo en `rph_sexo` que en
#' `rph_nivel_rec`, así que `vctrs` correctamente se niega a coercionar esas
#' columnas a un tipo común (`list_rbind()` falla con "loss of precision" si
#' no se hace este paso). La columna `label` ya lleva el significado legible,
#' así que no se pierde información.
tabla_cruces_cluster <- function(svy, clust_var, vars_fuente, vars_sec) {
    a_texto <- function(tabs) {
        purrr::map(tabs, ~ dplyr::mutate(.x, val = as.character(val)))
    }

    fuente <- tab_var_clust(
        svy = svy,
        clust_var = clust_var,
        vector_vars = vars_fuente,
        type_var_str = "fuente",
        invert = FALSE,
        save = FALSE
    ) |>
        a_texto() |>
        purrr::list_rbind() |>
        dplyr::mutate(grupo_variable = "fuente")

    secundarias <- tab_var_clust(
        svy = svy,
        clust_var = clust_var,
        vector_vars = vars_sec,
        type_var_str = "sec",
        invert = FALSE,
        save = FALSE
    ) |>
        a_texto() |>
        purrr::list_rbind() |>
        dplyr::mutate(grupo_variable = "secundaria")

    dplyr::bind_rows(fuente, secundarias) |>
        dplyr::relocate(grupo_variable)
}

#' Tabla 6 — `v-test` de la solución de cluster reportada
#'
#' PLAN.md F5.3. `FactoMineR::HCPC()` ya calcula esto (`desc.var$category`
#' dentro del target `hcpc`); acá solo se aplana a un tibble largo. Ordena las
#' categorías por cuánto distinguen a cada cluster (`v.test`), en vez de tener
#' que comparar veinte tablas a ojo.
#'
#' Depende de D2: la solución de cluster completa cambia si D2 cambia.
#'
#' @param hcpc Lista de objetos `HCPC` (`hcpc`, target).
#' @param clust_var `cfg$CLUSTER_A_SACAR` (p.ej. `"clusters_5"`), de donde se
#'   deriva qué solución usar.
#' @return Un tibble largo: `cluster | variable | categoria | Cla/Mod | Mod/Cla
#'   | Global | p.value | v.test`, ordenado por cluster y `v.test` descendente.
tabla_v_test <- function(hcpc, clust_var) {
    nclust <- stringr::str_extract(clust_var, "\\d+$")
    h <- hcpc[[paste0("class", nclust)]]
    dv <- h$desc.var$category

    purrr::imap(dv, function(mat, cluster_id) {
        tibble::as_tibble(mat, rownames = "variable_categoria") |>
            tidyr::separate(
                variable_categoria,
                into = c("variable", "categoria"),
                sep = "=",
                extra = "merge"
            ) |>
            dplyr::mutate(cluster = cluster_id) |>
            dplyr::relocate(cluster, variable, categoria)
    }) |>
        purrr::list_rbind() |>
        dplyr::arrange(cluster, dplyr::desc(v.test))
}

#' Escribir una tabla descriptiva a Excel + CSV, con sello de estado
#'
#' PLAN.md F5.3, "Formato de salida": targets `format = "file"`, Excel para el
#' entregable, CSV al lado por `F0.3` (registro versionado diffeable). Si
#' `motivo_provisional` no es `NULL`, estampa el aviso en las dos salidas — no
#' solo en el plan — para que nadie cite un número que va a cambiar sin saber
#' que puede cambiar.
#'
#' @param tabla Data frame a escribir.
#' @param ruta_base Ruta sin extensión (p.ej. `"output/tables/2025/variables_fuente"`).
#' @param sheet Nombre de la pestaña de datos en el Excel.
#' @param motivo_provisional `NULL` si la tabla es final, o un string
#'   describiendo qué decisión abierta puede cambiarla (p.ej. `"D2 abierta:
#'   la categorización de los índices puede cambiar estos números"`).
#' @return La ruta del `.xlsx` escrito, invisible.
escribir_tabla_descriptiva <- function(
    tabla,
    ruta_base,
    sheet = "datos",
    motivo_provisional = NULL
) {
    dir.create(dirname(ruta_base), recursive = TRUE, showWarnings = FALSE)

    wb <- openxlsx::createWorkbook()

    if (!is.null(motivo_provisional)) {
        openxlsx::addWorksheet(wb, "AVISO")
        openxlsx::writeData(
            wb,
            "AVISO",
            data.frame(
                aviso = "PROVISIONAL - no citar como número final",
                motivo = motivo_provisional
            )
        )
    }

    wb <- format_tab_excel(tabla, wb = wb, sheet = sheet)
    openxlsx::saveWorkbook(wb, paste0(ruta_base, ".xlsx"), overwrite = TRUE)

    tabla_csv <- tabla
    if (!is.null(motivo_provisional)) {
        tabla_csv <- tabla_csv |>
            dplyr::mutate(
                aviso_provisional = motivo_provisional,
                .before = 1
            )
    }
    readr::write_csv(tabla_csv, paste0(ruta_base, ".csv"))

    invisible(paste0(ruta_base, ".xlsx"))
}
