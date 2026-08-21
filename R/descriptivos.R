#' Construir el objeto de diseño muestral
#'
#' La ENUSC no se levanta por muestreo aleatorio simple: agrupa a las personas en
#' conglomerados y estratos, y eso hay que declararlo al estimar.
#'
#' @details
#' Las tres columnas se verifican antes de construir el objeto. `srvyr` acepta un
#' nombre de argumento mal escrito sin protestar y devuelve un diseño sin
#' estratificar, que produce estimaciones plausibles y mal calculadas. Fallar
#' acá con el nombre de la columna es preferible.
#'
#' @param datos Datos finales (`datos_finales`).
#' @param ids,strata,weights Nombres de columna, como string (`cfg$SVY_IDS`,
#'   `cfg$SVY_STRATA`, `cfg$SVY_WEIGHTS`).
#' @return Un objeto `srvyr::as_survey_design()`.
construir_diseno_muestral <- function(datos, ids, strata, weights) {
    faltantes <- setdiff(c(ids, strata, weights), names(datos))
    if (length(faltantes) > 0) {
        rlang::abort(c(
            "No se encontraron las columnas del diseño muestral.",
            x = paste("Faltan:", paste(faltantes, collapse = ", "))
        ))
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
#' El mapeo entre el nombre de la ENUSC y el que usa el análisis es derivable del
#' código, así que se deriva en vez de mantenerlo a mano. Reproduce la misma
#' selección que [seleccionar_variables()] para capturar, en el mismo orden, el
#' nombre original de cada columna antes de renombrarla.
#'
#' Si la selección cambia, hay que cambiar acá también: el `stopifnot` falla si
#' las dos se desincronizan en cantidad de columnas.
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

    if (length(originales) != length(nuestro)) {
        rlang::abort(c(
            "El mapeo de nombres quedó desincronizado de la selección.",
            x = paste0(
                "Originales: ", length(originales),
                "; renombradas: ", length(nuestro), "."
            ),
            i = "Si seleccionar_variables() cambió, hay que replicar el cambio acá."
        ))
    }

    tibble::tibble(original = originales, nuestro = nuestro)
}

#' Tabla 1 — Univariados de variables originales, por dimensión
#'
#' Corre sobre las variables originales, ya renombradas pero sin recodificar,
#' usando `cfg$PATRONES` para separar la pregunta del ítem en la etiqueta.
#'
#' @param datos `datos_seleccionados`.
#' @param cfg$PATRONES `cfg$PATRONES`.
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
#' Los índices `_pct` continuos y las variables que entran al modelo.
#'
#' @param datos `datos_finales`.
#' @param vars_continuas Los seis índices `_pct` sin categorizar.
#' @param vars_categorizadas `cfg$VARS_MODELO`.
#' @return Un tibble largo.
tabla_variables_fuente <- function(datos, vars_continuas, vars_categorizadas) {
    purrr::map(c(vars_continuas, vars_categorizadas), function(v) {
        tab_frq1(data = datos, var = !!rlang::sym(v), verbose = FALSE)
    }) |>
        purrr::list_rbind()
}

#' Tabla 3 — Univariados de variables secundarias
#'
#' Las variables que describen a los grupos sin participar del modelo.
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
#' Cuántas personas quedaron en cada grupo, para cada solución calculada.
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
#' El perfil de cada grupo: qué porcentaje de sus miembros cae en cada categoría
#' de cada variable. Se lee por columna, no por fila.
#'
#' @param svy Diseño muestral (`construir_diseno_muestral()`).
#' @param clust_var `cfg$CLUSTER_A_SACAR`.
#' @param vars_fuente `cfg$VARS_MODELO`.
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
#' `HCPC()` ya calcula esto; acá solo se aplana a un tibble largo. El propósito
#' es **ordenar** las categorías por cuánto distinguen a cada grupo, para poder
#' caracterizarlos y nombrarlos.
#'
#' @section Por qué no se ordena por `v.test`:
#' `FactoMineR` deriva `v.test` invirtiendo el p-value, y con casi 50.000 casos
#' el p subdesborda a 0, de modo que `qnorm(0)` devuelve `Inf`. Más de la mitad
#' de las filas quedan así, y el orden se pierde justo entre las asociaciones más
#' fuertes, que son las que sirven para nombrar el grupo.
#'
#' De fondo: a este tamaño de muestra casi todo da significativo, así que la
#' significancia deja de discriminar y lo que hay que mirar es el tamaño del
#' efecto.
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
#' Dos cosas, las dos sobre defectos que aparecen si no se hacen:
#'
#' 1. **Descarta las filas de categoría vacía.** `sjmisc::frq()` agrega una fila
#'    `val = NA` por variable aunque no haya ningún caso ahí. Se descartan
#'    **solo si `frq == 0`**: una fila `NA` con casos detrás es no respuesta
#'    real y tiene que sobrevivir.
#' 2. **Redondea.** Sin esto los CSV salen con ruido de coma flotante
#'    (`51.449999999999996`). Se excluyen `p.value` y `v.test`,
#'    donde redondear a dos decimales destruiría la información.
#'
#' Se aplica **antes** de bifurcar en Excel y CSV, de modo que las dos salidas
#' tengan exactamente las mismas filas y columnas.
#'
#' @section Por qué no se usa `pre_proc_excel()`:
#' Esa función convierte los números a **texto** en formato español, que sirve
#' para comparar archivos como strings exactos pero no para entregar: dejaría un
#' Excel donde no se puede ordenar ni calcular, y un CSV con comas decimales que
#' habría que volver a parsear.
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
#' Excel para el entregable y CSV al lado, que es el que se versiona y se puede
#' diffear entre corridas. Si `motivo_provisional` no es `NULL`, el aviso queda
#' estampado en las dos salidas, para que nadie cite un número que va a cambiar
#' sin saber que puede cambiar.
#'
#' @param tabla Data frame a escribir.
#' @param ruta_base Ruta sin extensión (p.ej. `"output/tables/2025/variables_fuente"`).
#' @param sheet Nombre de la pestaña de datos en el Excel.
#' @param motivo_provisional `NULL` si la tabla es final, o un string
#'   describiendo qué decisión abierta puede cambiarla (p.ej. `"la
#'   categorización de los índices puede cambiar estos números"`).
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
    #* error de format_tab_excel() sin contexto.
    if (!var_col %in% names(tabla)) {
        rlang::abort(c(
            paste0("La columna de agrupación '", var_col, "' no existe en la tabla."),
            x = paste("Columnas disponibles:", paste(names(tabla), collapse = ", "))
        ))
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
# Insumos de la página
#
# Regla: el `.qmd` no calcula. Todo número que aparezca en la página
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
#' inercia total, mecánicamente. Importa porque cambiar cómo se corta una
#' variable cambia exactamente eso.
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
        #* Los índices secundarios prorrateados dejan sin valor a quien respondió
        #* menos de la mitad de la batería. Esa categoría se nombra en vez de
        #* aparecer como NA: es no respuesta real y tiene que verse.
        dplyr::mutate(
            categoria = dplyr::coalesce(categoria, "Sin dato suficiente")
        ) |>
        tidyr::pivot_wider(
            names_from = dplyr::all_of(clust_var),
            values_from = prop,
            values_fill = 0
        ) |>
        dplyr::arrange(dplyr::desc(grupo_variable), variable)
}

#' `v-test` de todas las soluciones de cluster
#'
#' Igual que [tabla_v_test()] pero recorriendo las soluciones de `n_clases`, de
#' modo que la página pueda mostrarlas como subpestañas y no solo la reportada.
#'
#' @param hcpc Lista de objetos `HCPC` (target `hcpc`).
#' @param n_clases `cfg$N_CLASES`.
#' @return El mismo tibble de [tabla_v_test()] con una columna `solucion`.
tabla_v_test_todas <- function(hcpc, n_clases) {
    purrr::map(n_clases, function(k) {
        tabla_v_test(hcpc, paste0("clusters_", k)) |>
            dplyr::mutate(solucion = k, .before = 1)
    }) |>
        purrr::list_rbind()
}

#' Cruces por cluster, en formato ancho, para todas las soluciones
#'
#' El paso caro del pipeline en esta zona: cada solución estima sus cruces con
#' el diseño muestral por separado. Se aísla en su propio target para que
#' cambiar el formato de una tabla no obligue a recalcular las tres.
#'
#' @param svy Diseño muestral.
#' @param n_clases `cfg$N_CLASES`.
#' @param vars_fuente,vars_sec Vectores de variables.
#' @return Un tibble ancho con columna `solucion` y una columna por cluster.
#'   Las columnas de cluster que no existen en una solución quedan en `NA` —
#'   la de 4 grupos no tiene `C5` ni `C6`.
tabla_cruces_ancho_todas <- function(svy, n_clases, vars_fuente, vars_sec) {
    purrr::map(n_clases, function(k) {
        clust_var <- paste0("clusters_", k)

        tabla_cruces_cluster(
            svy = svy,
            clust_var = clust_var,
            vars_fuente = vars_fuente,
            vars_sec = vars_sec
        ) |>
            tabla_cruces_ancho(clust_var) |>
            dplyr::mutate(solucion = k, .before = 1)
    }) |>
        purrr::list_rbind()
}

#' Marginal ponderada de cada categoría, sobre los casos que entran al modelo
#'
#' El insumo que faltaba para calcular `lift_pp` sin pasar por `catdes()`.
#'
#' @section Por qué hace falta:
#' La página muestra dos estimaciones de la misma cantidad, una al lado de la
#' otra, calculadas distinto. [tabla_v_test()] toma `Mod/Cla` y `Global` de
#' `catdes()`, que corre **sin ponderar** sobre la matriz del modelo;
#' [tabla_cruces_cluster()] estima **con el diseño muestral**. Para "Sin
#' inseguridad en el barrio" en C1 de la solución de 5, la primera da 87,59% y
#' la segunda 87,34%. Para un informe sobre la población la estimación
#' ponderada es la defendible, así que `Global` tiene que existir en esa base.
#'
#' @section El universo, que es donde está la trampa:
#' `diseno_muestral` se construye sobre `datos_finales`, que son **55.796**
#' filas. Los clusters existen para **49.503**: hay 6.293 casos sin grupo. Los
#' porcentajes por cluster de [tabla_cruces_cluster()] ya salen sobre los
#' 49.503, porque `tab_var_clust()` filtra el diseño por `!is.na(clust_var)`.
#' Si `Global` se estimara sobre los 55.796, la resta compararía contra un
#' universo distinto del que forma los grupos, y el sesgo no sería neutro: la
#' exclusión está documentada como no aleatoria. De ahí el mismo filtro acá.
#'
#' Los 49.503 son **los mismos en las tres soluciones**, así que esta tabla se
#' calcula una vez y sirve para las tres.
#'
#' @section Alternativa descartada:
#' `Global` se puede reconstruir como promedio de las columnas de cluster
#' ponderado por el tamaño de cada grupo, sin tocar el diseño. Se verificó que
#' da lo mismo (discrepancia máxima 0,0077 pp, que es el redondeo a dos
#' decimales de `tab_frq2()`). Se descartó igual: depende de que el denominador
#' de cada bloque de variable siga siendo el tamaño del cluster, que hoy se
#' cumple porque la no respuesta entra como categoría propia, pero dejaría de
#' cumplirse en silencio si alguna variable futura excluyera sus `NA`.
#'
#' Las etiquetas se arman con `sjlabelled::to_label()`, igual que
#' [tab_frq2()], para que la clave `variable | categoria` calce con la de
#' [tabla_cruces_ancho_todas()]. La verificación del calce vive en
#' [tabla_lift_ponderado()], que es donde se usa.
#'
#' @param svy Diseño muestral (target `diseno_muestral`).
#' @param clust_var Nombre de una columna de cluster, para definir el universo.
#' @param vars Vector de variables a marginalizar. Recibe un solo vector y no
#'   uno por familia porque el cálculo es el mismo para todas: las del modelo y
#'   las secundarias van juntas para la matriz de perfiles, y las originales van
#'   solas para su propia tabla.
#' @return Un tibble `variable | categoria | global_pct`.
marginales_ponderadas <- function(svy, clust_var, vars) {
    svy_mod <- svy |> dplyr::filter(!is.na(.data[[clust_var]]))

    purrr::map(vars, function(v) {
        svy_mod |>
            srvyr::group_by(dplyr::across(dplyr::all_of(v))) |>
            srvyr::summarise(prop = srvyr::survey_mean()) |>
            dplyr::mutate(
                variable = v,
                categoria = as.character(sjlabelled::to_label(.data[[v]])),
                global_pct = round(prop * 100, 2)
            ) |>
            dplyr::select(variable, categoria, global_pct)
    }) |>
        purrr::list_rbind() |>
        #* Misma convención que tabla_cruces_ancho(): la categoría sin etiqueta
        #* se nombra en vez de quedar como NA.
        dplyr::mutate(
            categoria = dplyr::coalesce(categoria, "Sin dato suficiente")
        )
}

#' `lift_pp` ponderado, para todas las soluciones
#'
#' La versión con diseño muestral de lo que [tabla_v_test()] devuelve sin
#' ponderar. `lift_pp` es una resta entre dos porcentajes, así que una vez que
#' la pertenencia a grupo es una columna del dato no hace falta volver a pasar
#' por `FactoMineR`.
#'
#' @section Dos diferencias con la versión de `catdes()`:
#' 1. **La grilla queda completa.** `catdes()` devuelve solo las categorías que
#'    pasan un umbral de significancia: en la solución de 5 son 115 de las 120
#'    combinaciones posibles. Acá están las 120, porque el corte por
#'    significancia se saca del cálculo y pasa a ser, si se quiere, una decisión
#'    de presentación sobre `lift_pp`, que está en la escala que se muestra.
#' 2. **Incluye las variables secundarias.** `catdes()` describe solo las ocho
#'    del modelo. Sexo, edad, NSE, macrozona, victimización y medios no tenían
#'    ninguna medida de contraste contra el total.
#'
#' @section Por qué el join se verifica y no se confía:
#' La clave es `variable | categoria`, o sea texto de etiqueta armado por dos
#' caminos distintos. Un `left_join()` que no encuentra pareja devuelve `NA` sin
#' quejarse, y la matriz saldría con huecos que parecerían categorías no
#' distintivas. Se usa `inner_join()` con una aserción de que ninguna de las dos
#' tablas perdió filas.
#'
#' @param cruces_ancho Target `cruces_ancho_todas`.
#' @param marginales Target `marginales_modelo`.
#' @return Un tibble
#'   `solucion | grupo | grupo_variable | variable | categoria | pct_grupo | global_pct | lift_pp`.
tabla_lift_ponderado <- function(cruces_ancho, marginales) {
    largo <- cruces_ancho |>
        tidyr::pivot_longer(
            dplyr::matches("^C\\d+$"),
            names_to = "grupo",
            values_to = "pct_grupo"
        ) |>
        #* La solución de 4 no tiene C5 ni C6: esas columnas existen en el tibble
        #* ancho y vienen en NA. Se descartan por número de grupo y no por NA,
        #* que podría enmascarar un dato faltante real.
        dplyr::filter(
            as.integer(stringr::str_remove(grupo, "^C")) <= solucion
        )

    if (anyNA(largo$pct_grupo)) {
        rlang::abort("Quedaron porcentajes en NA tras filtrar por solución.")
    }

    res <- largo |>
        dplyr::inner_join(marginales, by = c("variable", "categoria")) |>
        dplyr::mutate(lift_pp = pct_grupo - global_pct) |>
        dplyr::relocate(solucion, grupo, grupo_variable, variable, categoria)

    #* Si las etiquetas de los dos caminos dejan de calzar, esto tiene que
    #* fallar acá y no aparecer como una matriz con huecos más adelante.
    if (nrow(res) != nrow(largo)) {
        rlang::abort(c(
            "El join perdió filas: las etiquetas de categoría no calzan.",
            x = paste0("Entraron ", nrow(largo), " filas y salieron ", nrow(res), "."),
            i = "Las claves son texto de etiqueta armado por dos caminos distintos."
        ))
    }

    res
}

#' Rótulo legible de cada columna original
#'
#' Las etiquetas de la ENUSC repiten la pregunta entera en cada ítem de una
#' batería, así que puestas en una tabla ocupan una pantalla y no dejan ver qué
#' distingue a un ítem del siguiente. Esta función se queda con el ítem y le
#' antepone el nombre de la batería.
#'
#' @section Cómo se aísla el ítem:
#' Por el texto que las etiquetas de una batería **no** comparten: se descarta
#' el prefijo común y el sufijo común de las etiquetas del grupo, y lo que
#' queda es el ítem. Sirve para los tres formatos que trae el instrumento sin
#' un caso especial por dimensión: el ítem después de un signo de pregunta
#' ("...¿qué tan seguro/a se siente...? Trasladándose en su vehículo"), el ítem
#' después de un punto ("Indique el o los elementos... Perro u otro animal") y
#' el ítem entre comillas dentro de la pregunta ("...¿ha dejado de \"Caminar
#' solo/a\"?"), donde el sufijo común es justamente la comilla de cierre y el
#' signo final.
#'
#' @section Alternativa descartada:
#' `cfg$PATRONES` ya declara un separador por dimensión y lo usa la tabla de
#' univariados. No sirve acá: el separador de `perper` incluye "en su", de modo
#' que "Robo en su vivienda" se corta en el segundo separador y el ítem queda
#' como "Robo". Sobre cuatro de los catorce delitos del pronóstico el rótulo
#' saldría truncado, y son ítems que se leen uno contra otro.
#'
#' @section Por qué el rótulo lleva el nombre de la batería adelante:
#' Seis ítems tienen etiqueta repetida entre baterías: "No sabe", "No responde"
#' y "No tenemos ninguna medida de seguridad" existen en las dos baterías de
#' opción múltiple, y "Otro elemento de seguridad" también. En una tabla
#' ordenada por tamaño de la diferencia, donde las filas de distintas baterías
#' quedan intercaladas, un rótulo repetido no se puede atribuir.
#'
#' @param datos `datos_finales`.
#' @param vars_orig Las columnas originales (target `cfg_vars_originales`).
#' @param baterias `cfg$BATERIAS`.
#' @return Un tibble `variable | bateria | item | etiqueta`.
etiquetas_originales <- function(datos, vars_orig, baterias) {
    #* El prefijo común se calcula carácter a carácter y no con una expresión
    #* regular: las etiquetas traen signos de pregunta, comillas y paréntesis,
    #* que habría que escapar para construir el patrón.
    prefijo_comun <- function(x) {
        if (length(x) < 2) return("")
        ch <- strsplit(x, "")
        n <- min(lengths(ch))
        k <- 0L
        while (
            k < n &&
                length(unique(vapply(ch, \(z) z[k + 1L], character(1)))) == 1L
        ) {
            k <- k + 1L
        }
        substr(x[[1]], 1, k)
    }

    invertir <- function(s) {
        vapply(strsplit(s, ""), \(z) paste(rev(z), collapse = ""), character(1))
    }
    sufijo_comun <- function(x) invertir(prefijo_comun(invertir(x)))

    faltantes <- setdiff(vars_orig, names(datos))
    if (length(faltantes) > 0) {
        rlang::abort(c(
            "Hay columnas originales declaradas que no existen en los datos.",
            x = paste("Faltan:", paste(faltantes, collapse = ", "))
        ))
    }

    #* Una columna que matchea dos patrones, o ninguno, deja el rótulo sin
    #* batería y la tabla sale con filas que no se pueden atribuir. Tiene que
    #* fallar acá.
    match_bateria <- purrr::map(vars_orig, function(v) {
        names(baterias)[stringr::str_detect(v, baterias)]
    })
    names(match_bateria) <- vars_orig
    ambiguas <- match_bateria[lengths(match_bateria) != 1]

    if (length(ambiguas) > 0) {
        rlang::abort(c(
            "Cada columna original tiene que pertenecer a exactamente una batería.",
            x = paste(
                "Sin batería única:",
                paste(names(ambiguas), collapse = ", ")
            ),
            i = "Revisar los patrones de cfg$BATERIAS."
        ))
    }

    tibble::tibble(
        variable = vars_orig,
        bateria = unlist(match_bateria, use.names = FALSE),
        label = vapply(
            vars_orig,
            \(v) sjlabelled::get_label(datos[[v]]) %||% NA_character_,
            character(1),
            USE.NAMES = FALSE
        )
    ) |>
        dplyr::mutate(
            item = {
                p <- nchar(prefijo_comun(label))
                s <- nchar(sufijo_comun(label))
                stringr::str_squish(substr(label, p + 1L, nchar(label) - s))
            },
            .by = bateria
        ) |>
        dplyr::mutate(
            #* Lo que sobra del recorte en la batería donde el ítem va entre
            #* comillas dentro de la pregunta.
            item = stringr::str_squish(
                stringr::str_remove_all(item, '^["“]|["”]?\\??$')
            ),
            #* Las preguntas sueltas no tienen ítem que separar: el prefijo
            #* común de un solo elemento es vacío y el recorte devuelve la
            #* etiqueta entera. Se rotulan con el nombre de la batería. Es un
            #* `if` y no un `if_else()` porque la condición es del grupo entero,
            #* no de cada fila.
            etiqueta = if (dplyr::n() == 1) {
                bateria
            } else {
                paste0(bateria, ": ", item)
            },
            .by = bateria
        ) |>
        dplyr::select(variable, bateria, item, etiqueta)
}

#' Cruces de las variables originales por cluster, para todas las soluciones
#'
#' La versión para las columnas originales de [tabla_cruces_ancho_todas()]. Vive
#' en su propio target porque es el paso más caro de esta zona del pipeline:
#' son 67 columnas por tres soluciones, medido en unos 9 minutos, contra las 22
#' columnas de la tabla de variables del modelo y secundarias.
#'
#' @section Por qué no se agrega como una familia más de la tabla existente:
#' [tabla_cruces_cluster()] alimenta también la planilla del entregable, con su
#' formato ya acordado. Sumarle una tercera familia cambiaría esa salida y
#' obligaría a recalcular las 22 columnas cada vez que se toque el rótulo de una
#' original. Separadas, cada una se invalida sola.
#'
#' @param svy Diseño muestral.
#' @param n_clases `cfg$N_CLASES`.
#' @param vars_orig Las columnas originales (target `cfg_vars_originales`).
#' @return Un tibble ancho con columna `solucion` y una por cluster, igual
#'   estructura que [tabla_cruces_ancho_todas()] pero con `grupo_variable` en
#'   `"original"`.
tabla_cruces_originales_todas <- function(svy, n_clases, vars_orig) {
    purrr::map(n_clases, function(k) {
        clust_var <- paste0("clusters_", k)

        tab_var_clust(
            svy = svy,
            clust_var = clust_var,
            vector_vars = vars_orig,
            type_var_str = "original",
            invert = FALSE,
            save = FALSE
        ) |>
            #* Las originales mezclan dominios de valor (0/1, 1 a 4, 1 a 5), y
            #* list_rbind() aborta si la misma columna llega con tipos
            #* distintos. Misma conversión que hace tabla_cruces_cluster().
            purrr::map(\(x) dplyr::mutate(x, val = as.character(val))) |>
            purrr::list_rbind() |>
            dplyr::mutate(grupo_variable = "original") |>
            tabla_cruces_ancho(clust_var) |>
            dplyr::mutate(solucion = k, .before = 1)
    }) |>
        purrr::list_rbind()
}

#' Bloques terminales de las tres soluciones de cluster
#'
#' Las tres soluciones salen del mismo árbol y solo cambian dónde se corta, así
#' que no son quince grupos distintos: son unos pocos bloques que se subdividen.
#' Este target los identifica y da la correspondencia entre soluciones.
#'
#' @section Por qué se verifica el anidamiento en vez de asumirlo:
#' Que un corte más fino sea un refinamiento del anterior es lo esperable de un
#' agrupamiento jerárquico, pero `HCPC()` reordena y renumera las clases en cada
#' llamada, así que la correspondencia no se puede leer de los nombres. Si
#' alguna vez se cambiara el método de corte y las soluciones dejaran de estar
#' anidadas, toda la lectura por bloques de la página quedaría mal sin que nada
#' fallara. La aserción exige que **cada grupo de la solución más fina caiga
#' entero dentro de uno solo de la más gruesa**.
#'
#' @section Cómo se ordenan los bloques:
#' Por el número de grupo de la solución más fina. `HCPC()` reordena las clases
#' según el primer eje del MCA, así que ese número ya viene ordenado por la
#' dimensión que más inercia explica y los bloques quedan en un orden
#' interpretable en vez de arbitrario.
#'
#' @param datos `datos_finales`.
#' @param n_clases `cfg$N_CLASES`.
#' @return Un tibble `bloque | casos | clusters_4 | clusters_5 | clusters_6`,
#'   una fila por bloque terminal.
bloques_soluciones <- function(datos, n_clases) {
    k <- sort(n_clases)
    vars <- paste0("clusters_", k)

    d <- datos |>
        dplyr::filter(!is.na(.data[[vars[1]]])) |>
        dplyr::select(dplyr::all_of(vars))

    #* Para cada par de soluciones consecutivas, cada columna de la tabla
    #* cruzada (grupo de la solución fina) debe tener un solo valor distinto de
    #* cero: cae entero en un grupo de la gruesa.
    anidadas <- purrr::map_lgl(seq_len(length(vars) - 1), function(i) {
        tb <- table(d[[vars[i]]], d[[vars[i + 1]]])
        all(colSums(tb > 0) == 1)
    })

    if (!all(anidadas)) {
        rlang::abort(c(
            "Las soluciones de cluster no están anidadas.",
            i = "La lectura por bloques de la página deja de aplicar."
        ))
    }

    d |>
        dplyr::count(dplyr::across(dplyr::all_of(vars)), name = "casos") |>
        dplyr::arrange(.data[[vars[length(vars)]]]) |>
        dplyr::mutate(bloque = LETTERS[dplyr::row_number()], .before = 1)
}
