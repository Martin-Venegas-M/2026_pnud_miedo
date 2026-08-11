#' Tabla de frecuencias ponderada a partir de `sjmisc::frq()`
#'
#' Devuelve como tibble la tabla que arma `sjmisc::frq()`, agregando el nombre
#' de la variable y, opcionalmente, su etiqueta separada en pregunta y
#' categoría. Entrega solo estimaciones ponderadas, sin medidas de calidad;
#' para eso está [tab_frq2()].
#'
#' @param data Data frame con los datos. Por defecto `enusc`, que se toma del
#'   entorno donde se llame la función.
#' @param var Variable a tabular, sin comillas.
#' @param w Variable de ponderación. Por defecto `fact_pers_reg`.
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
#' incluye "en su", de modo que "Robo en su vivienda" queda como "Robo ".
tab_frq1 <- function(
    data = enusc,
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
        dplyr::mutate(variable = rlang::as_label(ensym(var))) %>%
        dplyr::relocate(variable, everything())

    # Si se quiere la etiqueta de la variable, incorporar y reordenar
    if (verbose) {
        var_label <- sjlabelled::get_label(
            data %>% pull({{ var }})
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
                    separate(
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
#' @param svyobj Objeto de diseño muestral (`srvyr::as_survey_design()`). Por
#'   defecto `enusc_svy`.
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
    svyobj = enusc_svy,
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
            frq = survey_total(...),
            prop = survey_mean(...), # * Se pasan los argumentos por si se quieren otras medidas de calidad para la proporción
        ) %>%
        # Crear cols informativas, formatear y ordenar tabla
        srvyr::mutate(
            label = to_label({{ var }}),
            across(starts_with("prop"), ~ round((. * 100), 2)),
            across(starts_with("frq"), ~ round(.)),
            variable = rlang::as_label(ensym(var))
        ) %>%
        dplyr::relocate(variable, val = {{ var }}, label, everything())

    if (grp) {
        tab <- tab %>%
            mutate(
                {{ grp_var }} := sjlabelled::to_label({{ grp_var }})
            ) %>%
            relocate({{ grp_var }}, .after = variable)
    }

    # Si se quiere la etiqueta de la variable, incorporar y reordenar
    if (verbose) {
        var_label <- sjlabelled::get_label(
            svyobj %>% pull({{ var }})
        )

        tab <- tab %>%
            dplyr::mutate(desc = var_label) %>%
            dplyr::relocate(desc, everything())

        # Si se quiere separar la etiqueta de la variable en dos columnas: la
        # pregunta constante y la categoria
        if (sep_verbose) {
            tab <- tab %>%
                separate(
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
    stopifnot(var_col %in% names(df))

    # Añadir pestaña y escribr datos
    addWorksheet(wb, sheet)
    writeData(wb, sheet, x = df, withFilter = FALSE)
    n_cols <- ncol(df)

    # Generar y añadir estilo header
    header_style <- createStyle(
        fgFill = color_header,
        textDecoration = "bold",
        halign = "center",
        valign = "center",
        border = "bottom",
        borderStyle = "thick"
    )
    addStyle(
        wb,
        sheet,
        header_style,
        rows = 1,
        cols = 1:n_cols,
        gridExpand = TRUE,
        stack = TRUE
    )

    # Añadir filtros y setear anchos
    addFilter(wb, sheet, row = 1, cols = 1:n_cols)
    setColWidths(wb, sheet, cols = 1:n_cols, widths = "auto")

    # Añadir borde inferior grueso por cada "variable"
    ends <- which(
        df[[var_col]] !=
            dplyr::lead(df[[var_col]], default = tail(df[[var_col]], 1))
    )

    if (length(ends)) {
        group_border <- createStyle(border = "bottom", borderStyle = sep_style)

        addStyle(
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
        saveWorkbook(wb, path, overwrite = TRUE)
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
#' Que la salida sea texto y no números es lo que permite comparar los Excel
#' generados contra el gold standard como strings exactos, sin tolerancias
#' numéricas (ver `tests/compare_gold.R`).
#'
#' Con `type = "tab_frq1"` se descarta la fila de `NA` y la columna `raw.prc`, y
#' se renombra `valid.prc` a `prc`.
pre_proc_excel <- function(x, type = "tab_frq1") {
    # Preprocesamiento
    if (type == "tab_frq1") {
        x <- x %>%
            filter(!is.na(val)) %>% # Sacamos la fila de NA
            mutate(
                # Pasamos a formato español
                frq = number(frq, big.mark = ".", decimal.mark = ","),
                across(
                    c(raw.prc, valid.prc, cum.prc),
                    ~ number(
                        .,
                        big.mark = ".",
                        decimal.mark = ",",
                        accuracy = 0.01
                    )
                )
            ) %>%
            select(-starts_with("raw")) %>% # Eliminamos la columna del raw
            rename(prc = valid.prc)
        return(x)
    }

    if (type == "tab_frq2") {
        x %>%
            mutate(
                # Pasamos a formato español
                frq = number(frq, big.mark = ".", decimal.mark = ","),
                prc = number(
                    prop,
                    big.mark = ".",
                    decimal.mark = ",",
                    accuracy = 0.01
                )
            ) %>%
            select(-starts_with("prop"))
    }
}

#' Análisis de correspondencias múltiples con clustering jerárquico
#'
#' Corre un MCA (`FactoMineR::MCA()`) sobre las variables categóricas de `data`
#' y sobre sus coordenadas aplica clustering jerárquico (`FactoMineR::HCPC()`)
#' pidiendo un número fijo de clases.
#'
#' @param data Data frame con la columna identificadora y las variables del
#'   modelo, todas como factores y sin `NA`.
#' @param n_class Número de clases a extraer del árbol jerárquico.
#' @param select Si es `TRUE`, selecciona con `...` las columnas a usar y las
#'   convierte a etiquetas antes de correr el MCA.
#' @param id_col Columna identificadora, que se excluye del modelo pero se
#'   conserva en la salida para poder pegar los clusters a la base.
#' @param ... Columnas a seleccionar. Solo se usa si `select = TRUE`.
#'
#' @return Una lista con tres elementos: `data` (los datos de entrada más la
#'   primera coordenada del MCA y la variable `clusters_{n_class}`), `acm` (el
#'   objeto MCA) y `clust` (el objeto HCPC).
#'
#' @details
#' Se usa `consol = FALSE`, es decir sin consolidación por k-means, de modo que
#' el resultado es determinista: no depende de una semilla y se reproduce entre
#' corridas. Verificado contra el gold standard, caso por caso, para las cinco
#' soluciones de 2 a 6 clases.
#'
#' En ~12.000 casos el MCA toma menos de un segundo y el HCPC unos 3.
mca_hcpc <- function(
    data,
    n_class = 6,
    select = FALSE,
    id_col = "rph_id",
    ...
) {
    if (select) {
        data <- data %>%
            dplyr::select(...) %>%
            dplyr::mutate(across(everything(), ~ sjlabelled::to_label(.)))
    }

    # Run MCA analysis
    acm <- FactoMineR::MCA(data %>% select(-{{ id_col }}), graph = FALSE)

    # Run cluster analysis
    clust <- FactoMineR::HCPC(
        acm,
        nb.clust = n_class,
        consol = FALSE,
        graph = FALSE
    )

    # Save acm scores and clusters in df
    data <- data %>%
        mutate(
            acm_scores1 = acm$ind$coord[, 1],
            "clusters_{n_class}" := clust$data.clust$clust
        )

    # Save all
    results <- list(data = data, acm = acm, clust = clust)

    return(results)
}

#' Biplot de las categorías del MCA
#'
#' Grafica las categorías en el plano de las dos primeras dimensiones,
#' coloreadas según su calidad de representación (cos2).
#'
#' @param obj Objeto MCA, es decir el elemento `acm` que devuelve [mca_hcpc()].
#'
#' @return Un objeto `ggplot`.
plot_mca <- function(obj) {
    obj %>%
        fviz_mca_var(
            repel = TRUE,
            col.var = "cos2", # color = calidad de representación
            gradient.cols = c("#B3CDE3", "#6497B1", "#03396C"),
            ggtheme = theme_minimal()
        ) +
        ggtitle("MCA: categorías (Dim1 vs Dim2)") +
        theme(legend.position = "right")
}

#' Mapa factorial de los clusters
#'
#' @param obj Objeto HCPC, es decir el elemento `clust` que devuelve
#'   [mca_hcpc()].
#'
#' @return Un objeto `ggplot`.
#'
#' @note
#' ! ESTA FUNCIÓN ESTÁ ROTA y hoy no la llama nadie: recibe `obj` pero por
#' dentro pasa `clust`, que no existe en su entorno. Corregirla implica decidir
#' si debe graficar `obj` directamente; se dejó sin tocar para no introducir un
#' cambio de comportamiento no solicitado.
plot_cluster <- function(obj) {
    obj %>%
        fviz_cluster(clust, geom = "point", main = "Factor map")
}

#' Nombres de las columnas de `enusc` que cumplen una selección
#'
#' Atajo para obtener un vector de nombres con la sintaxis de `dplyr::select()`.
#'
#' @param ... Expresiones de selección, por ejemplo `starts_with("emper")`.
#'
#' @return Un vector de caracteres con los nombres de las columnas.
#'
#' @note
#' Depende de que exista un objeto `enusc` en el entorno global: no recibe los
#' datos como argumento.
gen_vct <- function(...) {
    enusc %>%
        select(...) %>%
        names()
}

#' Construir una variable de porcentaje a partir de una batería de ítems
#'
#' Para cada caso calcula qué porcentaje de los ítems válidos de una batería
#' recibió alguna de las categorías consideradas "éxito". Los ítems codificados
#' como 85 ("No aplica") se excluyen del denominador, no cuentan como fracaso.
#'
#' @param data Data frame con la columna identificadora y los ítems fuente.
#' @param id.col Columna identificadora, sin comillas. Por defecto `rph_id`.
#' @param success.cats Categorías que cuentan como éxito. Por ejemplo `c(1, 2)`
#'   para "Muy inseguro" e "Inseguro".
#' @param source.cols Ítems fuente de la batería.
#' @param name.var.pct Nombre de la variable nueva, como string.
#' @param output Qué devolver: `"data"` (los datos con la variable agregada),
#'   `"details"` (la tabla larga intermedia con los conteos por caso),
#'   `"insumo"` (solo identificador y variable nueva) o `"all"` (las tres).
#'
#' @return Según `output`; por defecto el data frame de entrada con la variable
#'   nueva unida por `id.col`.
#'
#' @details
#' Cuando todos los ítems de un caso son 85, el denominador queda en 0 y el
#' resultado es `NaN`. Esos casos los recupera después el bloque de imputación
#' de `2_recode.R`, que los lleva a 85. La función informa por consola cuántos
#' son, y `validar_rescate_no_aplica()` verifica que la imputación
#' efectivamente haya ocurrido.
create_var_pct <- function(
    data,
    id.col = rph_id,
    success.cats, # Categorías de las variables fuente que se consideran "exito". P.ej: c(1, 2) -> 1 = Muy inseguro y 2 = Inseguro
    source.cols, # Variables fuente para construir la variable nueva
    name.var.pct, # Nombre de la variable nuueva
    output = c("data", "details", "insumo", "all")
) {
    # Match args
    output <- match.arg(output)

    # Crear tabla long para hacer los calculos
    details <- data %>%
        select({{ id.col }}, {{ source.cols }}) %>%
        pivot_longer(
            cols = {{ source.cols }},
            names_to = "variable",
            values_to = "value"
        ) %>%
        group_by({{ id.col }}) %>%
        mutate(
            not_valid = sum(if_else(value == 85, 1, 0)),
            n_valid = n() - not_valid,
            n_success = sum(if_else(value %in% success.cats, 1, 0)),
            "{name.var.pct}" := (n_success / n_valid) * 100
        ) %>%
        ungroup() %>%
        select(-not_valid)

    # Avisar cuántos casos quedaron sin ningún ítem válido
    n_sin_validos <- details %>%
        dplyr::filter(n_valid == 0) %>%
        dplyr::distinct({{ id.col }}) %>%
        nrow()

    if (n_sin_validos > 0) {
        message(glue::glue(
            "  · {name.var.pct}: {n_sin_validos} caso(s) sin ningún ítem válido (todos 85) -> NaN, ",
            "se imputan a 85 más adelante"
        ))
    }

    # Guardar variable en insumo wide
    insumo <- details %>%
        select({{ id.col }}, {{ name.var.pct }}) %>%
        distinct({{ id.col }}, .keep_all = T)

    # Añadir a data
    data <- data %>% left_join(insumo)

    # Retornar!
    if (output == "data") {
        return(data)
    } else if (output == "details") {
        return(details)
    } else if (output == "insumo") {
        return(insumo)
    } else if (output == "all") {
        return(list(data = data, details = details, insumo = insumo))
    }
}
