
#' Tabla de frecuencias ponderada a partir de `sjmisc::frq()`
#'
#' Devuelve como tibble la tabla que arma `sjmisc::frq()`, agregando el nombre
#' de la variable y, opcionalmente, su etiqueta separada en pregunta y
#' categoría. Entrega solo estimaciones ponderadas, sin medidas de calidad;
#' para eso está [tab_frq2()].
#'
#' `data` es obligatorio a propósito: un default que lea del entorno global
#' hace que la función parezca andar cuando en realidad está tabulando otra cosa.
#' `w` sí lleva default porque es tidy-eval sobre `data`, no una lectura de
#' global.
#'
#' @param data Data frame con los datos.
#' @param var Variable a tabular, sin comillas.
#' @param w Variable de ponderación, sin comillas. Por defecto `fact_pers_reg`.
#' @param verbose Si es `TRUE`, agrega la etiqueta de la variable como columna.
#' @param sep_verbose Si es `TRUE`, separa esa etiqueta en `pregunta` y
#'   `categoria` según `pattern_verbose`.
#' @param pattern_verbose Expresión regular con la que se separa la etiqueta.
#' @param extraer_verbose Alternativa a `pattern_verbose` para las baterías
#'   donde el ítem va DENTRO de la pregunta y no después de un separador.
#'   Expresión regular con un grupo de captura: lo capturado va a `categoria` y
#'   `pregunta` queda como la etiqueta sin esa parte. Se usa en ENUSC 2025 para
#'   `comper`, donde el ítem quedó entre comillas (`¿ha dejado de \"Caminar
#'   solo/a\"?`).
#' @param ... Argumentos adicionales que se pasan a `sjmisc::frq()`.
#'
#' @return Un tibble con una fila por categoría de `var`.
#'
#' @details
#' Con `sep_verbose = TRUE` se descarta lo que quede después del segundo
#' separador, así que una etiqueta que contenga el patrón más de una vez pierde
#' texto. Pasa con `perper_p_delito_pronostico_1`: el patrón de esa batería
#' incluye "en su", de modo que "Robo en su vivienda" queda como "Robo ". **No
#' se corrige acá** — es el bug conocido que Q1 deja para después, como paso
#' separado con el log mostrando el delta.
tab_frq1 <- function(
    data,
    var,
    w = fact_pers_reg,
    verbose = TRUE,
    sep_verbose = TRUE,
    pattern_verbose = "\\? ",
    extraer_verbose = NULL,
    ...
) {
    # Extraer el df que da sjmisc::frq() por defecto (muy bueno!)
    tab <- data %>%
        sjmisc::frq({{ var }}, weights = {{ w }}, ...) # * Se pasan los argumentos por si se quiere usar las funcionalidades de sjmisc::frq()

    # Crear col de variable y reordenar
    tab <- tab[[1]] %>%
        tibble::as_tibble() %>%
        dplyr::mutate(variable = rlang::as_label(rlang::ensym(var))) %>%
        dplyr::relocate(variable, everything())

    # Si se quiere la etiqueta de la variable, incorporar y reordenar
    if (verbose) {
        var_label <- sjlabelled::get_label(
            data %>% dplyr::pull({{ var }})
        )

        tab <- tab %>%
            dplyr::mutate(desc = var_label) %>%
            dplyr::relocate(desc, everything())

        # Si se quiere separar la etiqueta de la variable en dos columnas: la
        # pregunta constante y la categoria
        if (sep_verbose) {
            #* Una misma dimensión puede mezclar formatos de etiqueta: en 2025
            #* los 13 ítems de p_mod_actividades van entrecomillados, pero
            #* costos_medidas sigue usando separador. Si la extracción no aplica
            #* a esta etiqueta, se cae al separador en vez de devolver NA.
            aplica_extraer <- !is.null(extraer_verbose) &&
                !is.na(stringr::str_match(var_label, extraer_verbose)[, 2])

            if (!aplica_extraer) {
                tab <- tab %>%
                    tidyr::separate(
                        desc,
                        into = c("pregunta", "categoria"),
                        sep = pattern_verbose
                    )
            } else {
                #* Cuando el ítem va DENTRO de la pregunta no se puede cortar en
                #* un separador: se extrae con un grupo de captura y la pregunta
                #* queda como la etiqueta sin esa parte.
                tab <- tab %>%
                    dplyr::mutate(
                        categoria = stringr::str_match(desc, extraer_verbose)[,
                            2
                        ],
                        pregunta = stringr::str_squish(
                            stringr::str_remove(desc, extraer_verbose)
                        )
                    ) %>%
                    dplyr::select(-desc) %>%
                    dplyr::relocate(pregunta, categoria, everything())
            }
        }
    }

    return(tab)
}

#' Tabla de frecuencias sobre un objeto de diseño muestral
#'
#' Igual que [tab_frq1()] pero calculada con `srvyr` sobre un objeto de diseño
#' complejo, de modo que admite medidas de calidad (error estándar, intervalos
#' de confianza) además de la estimación puntual. Permite además cruzar por una
#' variable de grupo.
#'
#' `svyobj` es obligatorio, por lo mismo que en [tab_frq1()].
#'
#' @param svyobj Objeto de diseño muestral (`srvyr::as_survey_design()`).
#' @param grp Si es `TRUE`, convierte `grp_var` a etiquetas y la ubica junto a
#'   la columna `variable`.
#' @param grp_var Variable de agrupación, sin comillas.
#' @param var Variable a tabular, sin comillas.
#' @param verbose Si es `TRUE`, agrega la etiqueta de la variable como columna.
#' @param sep_verbose Si es `TRUE`, separa esa etiqueta en `pregunta` y
#'   `categoria` según `pattern_verbose`.
#' @param pattern_verbose Expresión regular con la que se separa la etiqueta.
#' @param ... Argumentos para `srvyr::survey_total()` y `survey_mean()`, por
#'   ejemplo `vartype = c("se", "ci")`. Con `vartype = NULL` se obtiene solo la
#'   estimación puntual.
#'
#' @return Un tibble con una fila por combinación de `grp_var` y `var`. Las
#'   proporciones vienen multiplicadas por 100 y redondeadas a 2 decimales.
#'
#' @details
#' El orden de `var` y `grp_var` define la dirección de lectura de los
#' porcentajes: son el porcentaje de `var` dentro de cada nivel de `grp_var`.
#' [tab_var_clust()] usa ese detalle para generar las tablas normales y las
#' invertidas con la misma función.
tab_frq2 <- function(
    svyobj,
    grp = FALSE,
    grp_var,
    var,
    verbose = TRUE,
    sep_verbose = TRUE,
    pattern_verbose = "\\? ",
    ...
) {
    # Crear tabla de frecuencias desde del objeto encuesta
    tab <- svyobj %>%
        srvyr::group_by({{ grp_var }}, {{ var }}) %>%
        srvyr::summarise(
            frq = srvyr::survey_total(...),
            prop = srvyr::survey_mean(...), # * Se pasan los argumentos por si se quieren otras medidas de calidad para la proporción
        ) %>%
        # Crear cols informativas, formatear y ordenar tabla
        srvyr::mutate(
            label = sjlabelled::to_label({{ var }}),
            dplyr::across(dplyr::starts_with("prop"), ~ round((. * 100), 2)),
            dplyr::across(dplyr::starts_with("frq"), ~ round(.)),
            variable = rlang::as_label(rlang::ensym(var))
        ) %>%
        dplyr::relocate(variable, val = {{ var }}, label, everything())

    if (grp) {
        tab <- tab %>%
            dplyr::mutate(
                {{ grp_var }} := sjlabelled::to_label({{ grp_var }})
            ) %>%
            dplyr::relocate({{ grp_var }}, .after = variable)
    }

    # Si se quiere la etiqueta de la variable, incorporar y reordenar
    if (verbose) {
        var_label <- sjlabelled::get_label(
            svyobj %>% dplyr::pull({{ var }})
        )

        tab <- tab %>%
            dplyr::mutate(desc = var_label) %>%
            dplyr::relocate(desc, everything())

        # Si se quiere separar la etiqueta de la variable en dos columnas: la
        # pregunta constante y la categoria
        if (sep_verbose) {
            tab <- tab %>%
                tidyr::separate(
                    desc,
                    into = c("pregunta", "categoria"),
                    sep = pattern_verbose
                )
        }
    }

    return(tab)
}

#' Escribir un data frame en una pestaña de Excel con formato
#'
#' Agrega `df` como una pestaña nueva del workbook, con encabezado de color,
#' filtros, anchos automáticos y un borde inferior que separa visualmente cada
#' grupo de filas de `var_col`.
#'
#'
#' @param df Data frame a escribir.
#' @param wb Workbook de `openxlsx` al que agregar la pestaña. Por defecto crea
#'   uno nuevo, lo que permite encadenar llamadas pasando el resultado anterior.
#' @param sheet Nombre de la pestaña. Excel lo limita a 31 caracteres.
#' @param color_header Color de fondo del encabezado, en hexadecimal.
#' @param var_col Columna que define los grupos de filas a separar con borde.
#'   Debe existir en `df`.
#' @param sep_style Estilo del borde separador (`"thick"`, `"dashed"`, etc.).
#' @param save Si es `TRUE`, guarda el workbook en `path` y no devuelve nada.
#' @param path Ruta de destino. Solo se usa si `save = TRUE`.
#'
#' @return El workbook modificado, salvo que `save = TRUE`.
format_tab_excel <- function(
    df,
    wb = openxlsx::createWorkbook(),
    sheet,
    color_header = "#478ec5",
    var_col = "variable",
    sep_style = "thick",
    save = FALSE,
    path
) {
    if (!var_col %in% names(df)) {
        rlang::abort(paste0("La columna de agrupación '", var_col, "' no existe."))
    }

    # Añadir pestaña y escribr datos
    openxlsx::addWorksheet(wb, sheet)
    openxlsx::writeData(wb, sheet, x = df, withFilter = FALSE)
    n_cols <- ncol(df)

    # Generar y añadir estilo header
    header_style <- openxlsx::createStyle(
        fgFill = color_header,
        textDecoration = "bold",
        halign = "center",
        valign = "center",
        border = "bottom",
        borderStyle = "thick"
    )
    openxlsx::addStyle(
        wb,
        sheet,
        header_style,
        rows = 1,
        cols = 1:n_cols,
        gridExpand = TRUE,
        stack = TRUE
    )

    # Añadir filtros y setear anchos
    openxlsx::addFilter(wb, sheet, row = 1, cols = 1:n_cols)
    openxlsx::setColWidths(wb, sheet, cols = 1:n_cols, widths = "auto")

    # Añadir borde inferior grueso por cada "variable"
    ends <- which(
        df[[var_col]] !=
            dplyr::lead(df[[var_col]], default = tail(df[[var_col]], 1))
    )

    if (length(ends)) {
        group_border <- openxlsx::createStyle(
            border = "bottom",
            borderStyle = sep_style
        )

        openxlsx::addStyle(
            wb,
            sheet,
            style = group_border,
            rows = ends + 1,
            cols = 1:n_cols,
            gridExpand = TRUE,
            stack = TRUE # +1 porque los datos comienzan en la fila 2 (fila 1 = encabezado)
        )
    }

    # Guardar si asi se solicita
    if (save) {
        openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
    } else {
        return(wb)
    }
}

#' Formatear números al estilo español antes de exportar a Excel
#'
#' Convierte las columnas numéricas a texto con punto como separador de miles y
#' coma como separador decimal, y descarta las columnas que no van al
#' entregable.
#'
#' @param x Tabla producida por [tab_frq1()] o [tab_frq2()].
#' @param type Origen de la tabla: `"tab_frq1"` o `"tab_frq2"`. Determina qué
#'   columnas se formatean y cuáles se eliminan.
#'
#' @return Un data frame con las columnas numéricas convertidas a texto.
#'
#' @details
#' Con `type = "tab_frq1"` se descarta la fila de `NA` y la columna `raw.prc`, y
#' se renombra `valid.prc` a `prc`.
pre_proc_excel <- function(x, type = "tab_frq1") {
    # Preprocesamiento
    if (type == "tab_frq1") {
        x <- x %>%
            dplyr::filter(!is.na(val)) %>% # Sacamos la fila de NA
            dplyr::mutate(
                # Pasamos a formato español
                frq = scales::number(frq, big.mark = ".", decimal.mark = ","),
                dplyr::across(
                    c(raw.prc, valid.prc, cum.prc),
                    ~ scales::number(
                        .,
                        big.mark = ".",
                        decimal.mark = ",",
                        accuracy = 0.01
                    )
                )
            ) %>%
            dplyr::select(-dplyr::starts_with("raw")) %>% # Eliminamos la columna del raw
            dplyr::rename(prc = valid.prc)
        return(x)
    }

    if (type == "tab_frq2") {
        x %>%
            dplyr::mutate(
                # Pasamos a formato español
                frq = scales::number(frq, big.mark = ".", decimal.mark = ","),
                prc = scales::number(
                    prop,
                    big.mark = ".",
                    decimal.mark = ",",
                    accuracy = 0.01
                )
            ) %>%
            dplyr::select(-dplyr::starts_with("prop"))
    }
}

#' Biplot de las categorías del MCA
#'
#' Grafica las categorías en el plano de las dos primeras dimensiones,
#' coloreadas según su calidad de representación (cos2).
#'
#' @param obj Objeto MCA, es decir el elemento devuelto por `ajustar_mca()`.
#'
#' @return Un objeto `ggplot`.
plot_mca <- function(obj) {
    obj %>%
        factoextra::fviz_mca_var(
            repel = TRUE,
            col.var = "cos2", # color = calidad de representación
            gradient.cols = c("#B3CDE3", "#6497B1", "#03396C"),
            ggtheme = ggplot2::theme_minimal()
        ) +
        ggplot2::ggtitle("MCA: categorías (Dim1 vs Dim2)") +
        ggplot2::theme(legend.position = "right")
}

#' Tablas de variables cruzadas por cluster
#'
#' Genera una tabla ponderada por cada variable del vector, cruzada contra la
#' variable de cluster, y opcionalmente las exporta todas a un mismo libro de
#' Excel con una pestaña por variable.
#'
#' `path` es obligatorio, por lo mismo que en [tab_frq1()].
#'
#' @param svy Objeto de diseño muestral. Se filtra internamente para dejar solo
#'   los casos con cluster asignado.
#' @param clust_var Nombre de la variable de cluster, como string. Por ejemplo
#'   `"clusters_5"`.
#' @param vector_vars Variables a cruzar contra el cluster.
#' @param type_var_str Etiqueta corta que identifica el conjunto de variables en
#'   el nombre del archivo (`"rec"`, `"sec"`, `"rec2"`).
#' @param invert Dirección de lectura de los porcentajes. Ver detalles.
#' @param save Si es `TRUE`, escribe el libro de Excel.
#' @param path Carpeta de destino. Solo se usa si `save = TRUE`.
#'
#' @return Una lista de tibbles, una por variable, con nombres truncados a 30
#'   caracteres para respetar el límite de Excel para nombres de pestaña.
#'
#' @details
#' Unifica lo que antes eran dos funciones casi idénticas: `tab_var_clust()` en
#' `analysis/descriptivos.R` y `tab_var_clust_inv()` en
#' `analysis/descriptivos_inverted.R`. La única diferencia sustantiva era qué
#' variable iba como `var` y cuál como `grp_var` en [tab_frq2()], lo que cambia
#' la dirección en que se leen los porcentajes:
#'
#' * `invert = FALSE`: % de cada categoría de la variable DENTRO de cada
#'   cluster.
#' * `invert = TRUE`: % de cada cluster DENTRO de cada categoría de la
#'   variable.
#'
#' **Ojo con `save = TRUE`:** escribe un `.xlsx` como efecto secundario, que va
#' contra la convención del resto del pipeline, donde la escritura vive en su
#' propio target `format = "file"`. Queda anotado; el DAG la llama siempre con
#' `save = FALSE`.
tab_var_clust <- function(
    svy,
    clust_var,
    vector_vars,
    type_var_str,
    invert = FALSE,
    save = FALSE,
    path
) {
    #* Se usa str_extract y no str_sub(-1) para no romperse con soluciones de
    #* 10+ clusters
    nclust <- stringr::str_extract(clust_var, "\\d+$")
    short_clust_var <- glue::glue("clust{nclust}")

    # Combinaciones de las tablas
    df <- tidyr::expand_grid(
        clust = clust_var,
        vars = vector_vars
    )

    # Objeto encuesta filtrado por casos validos del cluster
    svy <- svy %>% dplyr::filter(!is.na(.data[[clust_var]]))

    # Generar tablas: el orden de los argumentos es lo que define la dirección
    # de lectura
    x <- if (invert) df$clust else df$vars
    y <- if (invert) df$vars else df$clust

    clust_vars <- purrr::map2(
        x,
        y,
        ~ tab_frq2(
            svyobj = svy,
            var = !!rlang::sym(.x),
            grp = TRUE,
            grp_var = !!rlang::sym(.y),
            verbose = FALSE,
            vartype = NULL
        ),
        .progress = TRUE
    ) %>%
        rlang::set_names(
            stringr::str_trunc(
                glue::glue(
                    "{df$vars}-{stringr::str_replace(df$clust, clust_var, short_clust_var)}"
                ),
                30
            )
        )

    # Guardar si es necesario
    if (save) {
        sufijo <- if (invert) "_inverted" else ""

        wb_tabs <- purrr::reduce(
            seq_along(clust_vars),
            \(workbook, i) {
                format_tab_excel(
                    pre_proc_excel(clust_vars[[i]], type = "tab_frq2"),
                    wb = workbook,
                    sheet = names(clust_vars)[[i]],
                    var_col = names(clust_vars[[i]][2]),
                    sep_style = "dashed"
                )
            },
            .init = openxlsx::createWorkbook()
        )

        openxlsx::saveWorkbook(
            wb_tabs,
            glue::glue(
                "{path}/{type_var_str}_x_clust{nclust}_vars_tabs{sufijo}.xlsx"
            ),
            overwrite = TRUE
        )
    }

    return(clust_vars)
}
