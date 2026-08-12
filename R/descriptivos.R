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
#' dentro del target `hcpc`); acá solo se aplana a un tibble largo. El propósito
#' de la tabla es **ordenar** las categorías por cuánto distinguen a cada
#' cluster, para poder caracterizarlos y nombrarlos.
#'
#' Depende de D2: la solución de cluster completa cambia si D2 cambia.
#'
#' @section Por qué no se ordena por `v.test`:
#' `FactoMineR` deriva `v.test` invirtiendo el p-value, y con el N de este
#' proyecto (~49.500) el p subdesborda a 0, de modo que `qnorm(0)` devuelve
#' `Inf`. En la primera corrida de F5.3, **61 de 118 filas quedaron en `Inf`** y
#' el orden se perdía justo entre las asociaciones más fuertes, que son las que
#' sirven para nombrar el cluster.
#'
#' Se ordena entonces por `lift_pp = Mod/Cla - Global`: cuántos puntos
#' porcentuales más (o menos) prevalente es la categoría dentro del cluster que
#' en el total. Es finita siempre, interpretable en sus unidades, y conserva el
#' mismo signo que `v.test` (positiva = sobrerrepresentada). `v.test` y
#' `p.value` se conservan como columnas de referencia, con sus `Inf` intactos:
#' son el valor real que devuelve `HCPC`, no un error que haya que tapar.
#'
#' @param hcpc Lista de objetos `HCPC` (`hcpc`, target).
#' @param clust_var `cfg$CLUSTER_A_SACAR` (p.ej. `"clusters_5"`), de donde se
#'   deriva qué solución usar.
#' @return Un tibble largo: `cluster | variable | categoria | lift_pp | Cla/Mod
#'   | Mod/Cla | Global | p.value | v.test`, ordenado por cluster y `lift_pp`
#'   descendente.
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
        dplyr::mutate(lift_pp = .data[["Mod/Cla"]] - .data[["Global"]]) |>
        dplyr::relocate(lift_pp, .after = categoria) |>
        dplyr::arrange(cluster, dplyr::desc(lift_pp))
}

#' Dejar una tabla descriptiva lista para entregar
#'
#' Dos cosas, ambas sobre defectos observados en la primera corrida de F5.3:
#'
#' 1. **Descarta las filas de categoría vacía.** `sjmisc::frq()` agrega una fila
#'    `val = NA` por variable aunque no haya ningún caso ahí; en la primera
#'    corrida eran 104 filas `NA,NA,0,0` repartidas entre las cuatro tablas de
#'    frecuencias. Se descartan **solo si `frq == 0`**: una fila `NA` con casos
#'    detrás es no-respuesta real y tiene que sobrevivir, que es justamente la
#'    lección de §1 del plan.
#' 2. **Redondea.** Sin esto los CSV salían con ruido de coma flotante
#'    (`51.449999999999996`) en 177 líneas. Se excluyen `p.value` y `v.test`,
#'    donde redondear a dos decimales destruiría la información.
#'
#' Se aplica **antes** de bifurcar en Excel y CSV, de modo que las dos salidas
#' tengan exactamente las mismas filas y columnas.
#'
#' @section Por qué no se usa `pre_proc_excel()`:
#' F5.3 lo mencionaba, pero esa función convierte los números a **texto** en
#' formato español. Su propio docstring dice para qué: comparar los Excel contra
#' un gold como strings exactos. Eso es una necesidad del testbed, no del
#' entregable — y acá el registro versionado es el CSV, no el Excel. Convertir a
#' texto dejaría un entregable donde PNUD no puede ordenar ni calcular, y un CSV
#' con comas decimales que el testbed tendría que volver a parsear. Si en F5.1
#' el gold llega a necesitar el formato texto, se aplica ahí, sobre el Excel, y
#' no en el camino del CSV.
#'
#' @param tabla Data frame a limpiar.
#' @param decimales Decimales a los que redondear las columnas numéricas.
#' @return El data frame sin filas vacías y con los números redondeados.
limpiar_tabla_descriptiva <- function(tabla, decimales = 2) {
    if (all(c("val", "frq") %in% names(tabla))) {
        tabla <- dplyr::filter(tabla, !(is.na(val) & frq == 0))
    }

    #* p.value y v.test quedan fuera: el primero es 0 en buena parte de las
    #* filas y el segundo puede ser Inf (ver tabla_v_test()). Redondearlos no
    #* aporta y sí puede confundir.
    dplyr::mutate(
        tabla,
        dplyr::across(
            dplyr::where(is.numeric) & !dplyr::any_of(c("p.value", "v.test")),
            ~ round(.x, decimales)
        )
    )
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
    motivo_provisional = NULL,
    var_col = "variable"
) {
    tabla <- limpiar_tabla_descriptiva(tabla)

    #* format_tab_excel() dibuja un borde separador por cada grupo de var_col.
    #* No todas las tablas se agrupan por "variable": la de ajuste global se
    #* agrupa por dimensión. Falla temprano y con nombre en vez de dejar el
    #* stopifnot() de format_tab_excel() sin contexto.
    if (!var_col %in% names(tabla)) {
        stop(
            "escribir_tabla_descriptiva(): la columna de agrupación '",
            var_col,
            "' no existe en la tabla. Columnas: ",
            paste(names(tabla), collapse = ", ")
        )
    }

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

    wb <- format_tab_excel(tabla, wb = wb, sheet = sheet, var_col = var_col)
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

# ---------------------------------------------------------------------------
# Insumos de la página (PLAN.md F5.4)
#
# Regla de F5.4: el `.qmd` no calcula. Todo número que aparezca en la página
# nace acá, como target, para que sea trazable y para que la página se
# regenere sola cuando cambie una decisión.
# ---------------------------------------------------------------------------

#' Tabla de ajuste global del MCA
#'
#' Inercia por dimensión, que `FactoMineR::MCA()` ya deja en `$eig` y que hasta
#' ahora no se exponía.
#'
#' @section Advertencia de comparabilidad:
#' El % de inercia **no es comparable entre variantes de recodificación con
#' distinto número de categorías por variable**: más categorías producen más
#' inercia total, mecánicamente. Importa acá porque D2 cambia exactamente eso.
#' Para comparar variantes hace falta la corrección de Benzécri
#' (`GDAtools::modif.rate()`), que hoy no está implementada. Mientras tanto,
#' esta tabla describe la solución actual; no sirve para decir que una variante
#' es mejor que otra.
#'
#' @param mca Objeto `MCA` (target `mca`).
#' @param n_dim Cuántas dimensiones devolver.
#' @return Un tibble: `dimension | autovalor | pct_varianza | pct_acumulado`.
tabla_ajuste_global <- function(mca, n_dim = 10) {
    eig <- mca$eig
    n <- min(n_dim, nrow(eig))

    tibble::tibble(
        dimension = seq_len(n),
        autovalor = eig[seq_len(n), 1],
        pct_varianza = eig[seq_len(n), 2],
        pct_acumulado = eig[seq_len(n), 3]
    )
}

#' Mapa factorial de los clusters
#'
#' Reemplaza a `plot_cluster()`, que se eliminó en la Fase 1 por estar rota:
#' recibía `obj` pero por dentro pasaba `clust`, que no existía en su entorno.
#' `factoextra::fviz_cluster()` acepta el objeto `HCPC` directamente.
#'
#' @param hcpc Lista de objetos `HCPC` (target `hcpc`).
#' @param clust_var `cfg$CLUSTER_A_SACAR`, de donde se deriva qué solución usar.
#' @return Un objeto `ggplot`.
grafico_clusters <- function(hcpc, clust_var) {
    nclust <- stringr::str_extract(clust_var, "\\d+$")
    h <- hcpc[[paste0("class", nclust)]]

    factoextra::fviz_cluster(
        h,
        geom = "point",
        ggtheme = ggplot2::theme_minimal(),
        main = paste0("Mapa factorial de los ", nclust, " grupos")
    )
}

#' Cruces variable x cluster en formato ancho (la "Tabla C")
#'
#' Reorganiza `tabla5_cruces_cluster` al formato con el que el equipo lee los
#' perfiles: una fila por categoría, una columna por cluster, y el porcentaje
#' de esa categoría **dentro** de cada cluster. Las columnas de cada bloque de
#' variable suman 100.
#'
#' No recalcula nada: es un pivote de la tabla ya estimada con el diseño
#' muestral. Vive como target y no como chunk del `.qmd` porque es una tabla
#' del entregable, no una decoración.
#'
#' @section Celdas sin casos:
#' `srvyr` no devuelve fila para una combinación categoría x cluster que no
#' tiene ningún caso, así que el pivote deja `NA` ahí. En esta tabla eso
#' significa inequívocamente **0%**: son porcentajes que suman 100 dentro de
#' cada cluster, y una celda ausente es una categoría que nadie de ese cluster
#' eligió. Se rellenan con `0` para no mostrar un blanco que se lea como "dato
#' faltante" — que es justamente la confusión que originó este repo, acá al
#' revés.
#'
#' La inconsistencia se ve cruda en los datos: para la misma categoría,
#' `srvyr` devuelve `0` en un cluster y ninguna fila en otro. Son lo mismo.
#'
#' Ojo: este relleno es válido **solo** para esta tabla, por ser un cruce de
#' proporciones dentro de cluster. No generalizarlo a otras.
#'
#' @param cruces `tabla5_cruces_cluster`.
#' @param clust_var `cfg$CLUSTER_A_SACAR`, que nombra la columna de cluster.
#' @return Un tibble ancho: `grupo_variable | variable | categoria | <un
#'   cluster por columna>`.
tabla_cruces_ancho <- function(cruces, clust_var) {
    cruces |>
        dplyr::select(
            grupo_variable,
            variable,
            categoria = label,
            dplyr::all_of(clust_var),
            prop
        ) |>
        tidyr::pivot_wider(
            names_from = dplyr::all_of(clust_var),
            values_from = prop,
            values_fill = 0
        ) |>
        dplyr::arrange(dplyr::desc(grupo_variable), variable)
}
