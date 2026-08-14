
#' Construir una variable de porcentaje a partir de una batería de ítems
#'
#' Para cada caso, qué porcentaje de los ítems de una batería recibió alguna de
#' las categorías que cuentan como "éxito".
#'
#' @details
#' Los ítems en `85` ("no aplica") **salen del denominador**: la situación no le
#' corresponde a esa persona, así que no puede contar en su contra. Los `88`
#' ("no sabe") y `99` ("no responde") **se quedan**, y cuentan como no adhesión.
#' Es una convención conservadora y deliberada: quien no supo responder no se
#' asume que sí.
#'
#' @param data Data frame con la columna identificadora y los ítems fuente.
#' @param id.col Columna identificadora, sin comillas.
#' @param success.cats Categorías que cuentan como éxito.
#' @param source.cols Ítems fuente de la batería.
#' @param name.var.pct Nombre de la variable nueva, como string.
#' @param output Qué devolver: `"data"`, `"details"`, `"insumo"` o `"all"`.
#' @return Según `output`; por defecto `data` con la variable nueva agregada.
create_var_pct <- function(
    data,
    id.col = rph_id,
    success.cats,
    source.cols,
    name.var.pct,
    output = c("data", "details", "insumo", "all")
) {
    output <- match.arg(output)

    details <- data |>
        dplyr::select({{ id.col }}, {{ source.cols }}) |>
        tidyr::pivot_longer(
            cols = {{ source.cols }},
            names_to = "variable",
            values_to = "value"
        ) |>
        dplyr::group_by({{ id.col }}) |>
        dplyr::mutate(
            not_valid = sum(dplyr::if_else(value == 85, 1, 0)),
            n_valid = dplyr::n() - not_valid,
            n_success = sum(dplyr::if_else(value %in% success.cats, 1, 0)),
            "{name.var.pct}" := (n_success / n_valid) * 100
        ) |>
        dplyr::ungroup() |>
        dplyr::select(-not_valid)

    n_sin_validos <- details |>
        dplyr::filter(n_valid == 0) |>
        dplyr::distinct({{ id.col }}) |>
        nrow()

    if (n_sin_validos > 0) {
        message(glue::glue(
            "  · {name.var.pct}: {n_sin_validos} caso(s) sin ningún ítem válido (todos 85) -> NaN, ",
            "se imputan a 85 más adelante"
        ))
    }

    insumo <- details |>
        dplyr::select({{ id.col }}, {{ name.var.pct }}) |>
        dplyr::distinct({{ id.col }}, .keep_all = TRUE)

    data <- data |> dplyr::left_join(insumo)

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

#' Construir los cuatro índices `_pct`
#'
#' Aplica [create_var_pct()] a las cuatro baterías cuyo denominador varía de
#' persona a persona, que son las que necesitan expresarse como porcentaje.
#'
#' @details
#' **Qué columnas entran en cada batería es una decisión, no un detalle.** Las
#' preguntas de opción múltiple traen una columna por alternativa, y entre ellas
#' una que registra "ninguna". Si esa columna se incluye como una alternativa
#' más, quien responde "ninguna medida" obtiene un éxito y nunca llega a 0%.
#' Queda fuera a propósito: así el cero sale del cálculo mismo, sin necesidad de
#' un caso especial.
#'
#' @param datos Datos con las columnas fuente.
#' @param spec `cfg$INDICES`: ítems fuente por batería.
#' @return `datos` con las cuatro columnas `_pct` agregadas.
construir_indices_pct <- function(datos, spec) {
    #* Los dos índices de comgen salieron de acá en agosto de 2026: sus baterías
    #* no admiten el código 85, así que el denominador es constante y el
    #* porcentaje no aportaba nada sobre el conteo. Se categorizan directo desde
    #* los ítems en categorizar_indices(). Los cuatro que quedan sí tienen
    #* denominador variable y el porcentaje normaliza sobre lo aplicable.
    datos <- create_var_pct(
        datos,
        success.cats = c(1, 2),
        source.cols = spec[["emper_ep_pct"]],
        name.var.pct = "emper_ep_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = c(1, 2),
        source.cols = spec[["emper_barrio_pct"]],
        name.var.pct = "emper_barrio_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = c(1, 2),
        source.cols = spec[["emper_casa_pct"]],
        name.var.pct = "emper_casa_pct"
    )
    datos <- create_var_pct(
        datos,
        success.cats = 1,
        source.cols = spec[["comper_pct"]],
        name.var.pct = "comper_pct"
    )
    datos
}

#' Categoría de expectativa de victimización (`perper_delito`)
#'
#' Cruza dos preguntas para dar una sola variable de seis categorías. La
#' pregunta filtro es si la persona cree que será víctima de algún delito en los
#' próximos doce meses; a quien responde que sí se le muestra una batería de
#' tipos de delito, donde puede marcar varios.
#'
#' | Categoría | Quién cae ahí |
#' |---|---|
#' | 1 | Respondió que no a la pregunta filtro |
#' | 2 | Marcó algún delito clasificado como no violento |
#' | 3 | Marcó algún delito clasificado como violento |
#' | 4 | No respondió la pregunta filtro |
#' | 5 | Marcó únicamente "otro delito" |
#' | 6 | No respondió la batería |
#'
#' @details
#' **"Otro delito" y "no sabe qué delito" son categorías distintas.** Las dos
#' viven en la misma batería y es tentador juntarlas, pero marcar "otro delito"
#' es una respuesta sustantiva: esa persona sí espera ser víctima. Separarlas
#' recupera 78 casos para el modelo, que antes se descartaban como no respuesta.
#'
#' **El orden de las ramas decide los casos mixtos.** La batería admite marcar
#' varios delitos, y quien marca uno violento y uno no violento tiene que quedar
#' en una sola categoría. Como la rama de no violento se evalúa primero, esas
#' personas caen ahí. Son unas 7.900, así que el orden no es un detalle.
#'
#' @param datos Datos con las columnas fuente de `perper_delito`.
#' @return `datos` con la columna `perper_delito` agregada (6 categorías).
construir_perper_delito <- function(datos) {
    datos |>
        dplyr::mutate(
            perper_delito = dplyr::case_when(
                dplyr::if_all("perper_p_expos_delito", ~ . == 2) ~ 1,
                dplyr::if_any(
                    paste0("perper_p_delito_pronostico_", c(1:4, 6, 9:11)),
                    ~ . == 1
                ) ~
                    2,
                dplyr::if_any(
                    paste0("perper_p_delito_pronostico_", c(5, 7:8)),
                    ~ . == 1
                ) ~
                    3,
                dplyr::if_all("perper_p_expos_delito", ~ . %in% c(88, 99)) ~ 4,
                dplyr::if_any(
                    "perper_p_delito_pronostico_77",
                    ~ . == 1
                ) ~
                    5,
                dplyr::if_any(
                    paste0("perper_p_delito_pronostico_", c(88, 99)),
                    ~ . == 1
                ) ~
                    6,
                TRUE ~ NA
            )
        )
}

#' Gasto en medidas de seguridad (`comper_gasto`)
#'
#' La pregunta registra el gasto del hogar en medidas de seguridad en cinco
#' tramos. El análisis no usa el monto, solo si hubo gasto, así que los cinco se
#' colapsan en uno.
#'
#' @details
#' **El código 85 no significa "no aplica" en esta pregunta.** Su etiqueta es
#' "No ha gastado en medidas de seguridad": es una respuesta sustantiva, y entra
#' como 0 y no como dato faltante.
#'
#' El código `96` ("sin dato") no está cubierto y cae al `NA` final. Es un caso
#' entre casi 56.000.
#'
#' @param datos Datos con la columna `comper_costos_medidas`.
#' @return `datos` con la columna `comper_gasto` agregada.
construir_comper_gasto <- function(datos) {
    datos |>
        dplyr::mutate(
            comper_gasto = dplyr::case_when(
                dplyr::if_all("comper_costos_medidas", ~ . %in% c(1:5)) ~ 1,
                dplyr::if_all("comper_costos_medidas", ~ . == 85) ~ 0,
                dplyr::if_all("comper_costos_medidas", ~ . == 88) ~ 88,
                dplyr::if_all("comper_costos_medidas", ~ . == 99) ~ 99,
                TRUE ~ NA
            )
        )
}


#' Cuántas situaciones le aplican a cada persona en los índices de dos ítems
#'
#' Diagnóstico de un supuesto que el método `"valor"` deja implícito.
#'
#' @section Qué problema mide:
#' `emper_barrio_pct` y `emper_casa_pct` se construyen con dos ítems, "de día" y
#' "cuando ya está oscuro", y se categorizan por el valor del índice (0, 50 o
#' 100). Eso da por sentado que a todo el mundo le aplican los dos momentos,
#' pero los ítems admiten el código 85 y a mucha gente le aplica uno solo:
#' `create_var_pct()` normaliza sobre lo aplicable, así que quien declara
#' inseguridad en su único momento aplicable llega a 100 y cae en la misma
#' categoría que quien la declara en los dos.
#'
#' El cálculo es consistente con la convención del proyecto (normalizar sobre lo
#' aplicable, igual que en espacio público y en prácticas). Lo que no calza es la
#' etiqueta de la categoría 3, que afirma "de día y de noche" para gente con un
#' solo momento observado.
#'
#' @section Por qué es un target y no un chunk:
#' Para que la página pueda citar las cifras sin calcularlas, y para que el
#' diagnóstico se rehaga solo cuando cambie la versión de la encuesta. La
#' proporción de casos con un ítem no aplicable puede moverse entre años.
#'
#' @param datos_sel `datos_seleccionados`, con los ítems originales.
#' @param datos_cat Datos con las columnas `_cat` ya construidas.
#' @param spec `cfg$INDICES`, para saber qué ítems componen cada índice.
#' @param cortes `cfg$CORTES`, para quedarse con los de método `"valor"`.
#' @return Un tibble `indice | n_aplica | categoria | n`.
medir_aplicabilidad <- function(datos_sel, datos_cat, spec, cortes) {
    vars <- names(cortes)[
        vapply(cortes, \(s) s$metodo == "valor", logical(1))
    ]

    stopifnot(
        "medir_aplicabilidad(): ningún índice usa el método 'valor'" = length(
            vars
        ) >
            0
    )

    purrr::map(vars, function(v) {
        m <- vapply(
            datos_sel[spec[[v]]],
            \(x) as.numeric(haven::zap_labels(x)),
            numeric(nrow(datos_sel))
        )
        #* `n_valid` en create_var_pct() descuenta solo el 85: los otros códigos
        #* especiales cuentan en el denominador como no adhesión.
        n_aplica <- rowSums(m != 85)
        categoria <- as.numeric(haven::zap_labels(
            datos_cat[[paste0(v, "_cat")]]
        ))

        tibble::tibble(indice = v, n_aplica = n_aplica, categoria = categoria) |>
            dplyr::filter(categoria %in% 1:3) |>
            dplyr::count(indice, n_aplica, categoria)
    }) |>
        purrr::list_rbind()
}

#' Categorías de `comgen` a partir del conteo de medidas
#'
#' Sale de [categorizar_indices()], que hasta agosto de 2026 tenía una rama
#' `"conteo"` para estas dos variables. Esa rama no tocaba ningún índice: leía la
#' batería de ítems, no la columna `_pct`, y por eso obligaba a la función a
#' recibir un `spec_items` y a validar de forma distinta según el método. La
#' función que categoriza índices vuelve a hacer solo eso.
#'
#' @section Por qué se cuenta y no se saca un porcentaje:
#' Ningún ítem de estas dos baterías admite el código 85, así que el denominador
#' es constante y lo interpretable es cuántas medidas declara la persona. Los
#' umbrales son distintos entre vivienda y barrio a propósito: entre quienes
#' declaran una sola medida comunitaria, el 66% es un grupo de WhatsApp,
#' mientras que en la vivienda la medida única más común son rejas.
#'
#' @section La aserción:
#' La misma que en [categorizar_indices()]: ningún valor del conteo puede caer
#' en más de una categoría. Acá es casi trivial porque se corta sobre enteros,
#' pero se mantiene para que el invariante valga en las seis variables y no en
#' cuatro.
#'
#' @section Los códigos de no respuesta se estampan acá:
#' Quien responde "no sabe" a la batería completa tiene las columnas de medidas
#' todas en 0, así que el conteo le da 0 y caería en "sin medidas", que es una
#' respuesta sustantiva que no dio. Lo único que lo distingue son las columnas
#' `_ns`/`_nr`, declaradas en `cfg$CODIGOS_COMGEN`. Se aplican en esta misma
#' función y no en un paso posterior porque son códigos especiales **de esta
#' batería**: quien construye la variable se hace cargo de ellos.
#'
#' @param datos Datos con las baterías de ítems.
#' @param cortes Las entradas de método `"conteo"` de `cfg$CORTES`.
#' @param items `cfg$INDICES`, para saber qué columnas componen cada batería.
#' @param codigos `cfg$CODIGOS_COMGEN`: las columnas `_ns`/`_nr` de cada
#'   batería.
#' @return `datos` con una columna `{nombre}_cat` por cada batería.
categorizar_comgen <- function(datos, cortes, items, codigos) {
    faltan <- setdiff(unlist(items[names(cortes)]), names(datos))
    if (length(faltan) > 0) {
        stop(
            "categorizar_comgen(): faltan columnas de la batería: ",
            paste(faltan, collapse = ", ")
        )
    }

    for (v in names(cortes)) {
        m <- as.matrix(as.data.frame(lapply(
            datos[items[[v]]],
            \(col) as.numeric(haven::zap_labels(col))
        )))
        conteo <- rowSums(m == 1)
        cats <- cut(
            conteo,
            breaks = c(-1, cortes[[v]]$cortes, Inf),
            labels = FALSE
        )

        reparto <- tapply(cats, conteo, \(g) length(unique(g[!is.na(g)])))
        if (any(reparto > 1, na.rm = TRUE)) {
            stop(
                "categorizar_comgen(): en '",
                v,
                "' el corte parte conteos idénticos entre categorías"
            )
        }

        datos[[paste0(v, "_cat")]] <- cats
    }

    #* El 88/99 se estampa después de cortar y pisa lo que haya: quien marcó
    #* "no sabe" para toda la batería tiene conteo 0 y habría quedado en la
    #* categoría de "sin medidas".
    for (destino in names(codigos)) {
        marcas <- codigos[[destino]]
        datos[[destino]] <- dplyr::case_when(
            datos[[marcas[["ns"]]]] == 1 ~ 88,
            datos[[marcas[["nr"]]]] == 1 ~ 99,
            TRUE ~ datos[[destino]]
        )
    }

    datos
}

#' Las cuatro variables del modelo que no pasan por un índice
#'
#' Un solo paso del pipeline para todo lo que se construye directo desde las
#' columnas originales: `perper_delito` y `comper_gasto`, que combinan
#' respuestas del cuestionario sin pasar por un índice, y las dos de `comgen`,
#' que se cuentan sobre su batería.
#'
#' @section Por qué envuelve en vez de fundir:
#' Las tres lógicas son distintas y cada una carga su propia documentación: cómo
#' se arman las categorías de expectativa de victimización vive en
#' [construir_perper_delito()], y el criterio de los umbrales de `comgen` en
#' [categorizar_comgen()]. Fundirlas dejaría un docstring cubriendo tres
#' decisiones sin relación. Lo que se unifica es el **paso del pipeline**, no la
#' lógica: un target y un log en vez de tres.
#'
#' @param datos Datos con los índices `_pct` ya construidos.
#' @param cortes `cfg$CORTES`; se usan solo las entradas de método `"conteo"`.
#' @param items `cfg$INDICES`.
#' @param codigos `cfg$CODIGOS_COMGEN`.
#' @return `datos` con las cuatro variables agregadas.
construir_vars_sin_indice <- function(datos, cortes, items, codigos) {
    conteo <- cortes[vapply(cortes, \(s) s$metodo == "conteo", logical(1))]

    stopifnot(
        "construir_vars_sin_indice(): ninguna variable usa el método 'conteo'" = length(
            conteo
        ) >
            0
    )

    datos |>
        construir_perper_delito() |>
        construir_comper_gasto() |>
        categorizar_comgen(conteo, items, codigos)
}
