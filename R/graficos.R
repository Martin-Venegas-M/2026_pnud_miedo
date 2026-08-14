# Insumos de los gráficos de la página
#
# Estas funciones NO dibujan: preparan los datos que el .qmd grafica. El corte
# es deliberado. Todo lo que sea cálculo —coordenadas, centroides, la matriz de
# covarianza de una elipse— vive acá, como target, y queda trazable. El dibujo
# es presentación y vive en el .qmd, donde se puede ajustar sin invalidar el DAG.
#
# Se preparan a mano en vez de usar los gráficos por defecto de factoextra,
# que sirven para explorar pero no para comunicar: no distinguen dimensión
# teórica, superponen etiquetas y dibujan un punto por persona donde solo se
# necesita leer dónde está el núcleo de cada grupo.

#' Coordenadas de las categorías en el plano principal
#'
#' Una fila por categoría de respuesta, con su posición en las dos primeras
#' dimensiones del MCA y la dimensión teórica de la que proviene.
#'
#' `cos2` es la calidad de representación: cuánto de la categoría queda
#' explicado por esas dos dimensiones. Sin él, un punto mal representado se lee
#' como si estuviera donde no está.
#'
#' @details
#' `FactoMineR` nombra las filas de `var$coord` solo con el nivel, sin decir de
#' qué variable viene. La correspondencia se reconstruye desde `call$X`, que es
#' el data frame con el que se ajustó el modelo. Sin esto no se puede colorear
#' el mapa por dimensión, que es la agrupación que el lector necesita para
#' interpretarlo.
#'
#' @param mca Objeto `MCA` (target `mca`).
#' @return Un tibble: `dimension | variable | categoria | dim1 | dim2 | cos2`.
datos_biplot <- function(mca) {
    var_de_categoria <- purrr::imap(
        mca$call$X,
        \(col, nombre) tibble::tibble(categoria = levels(col), variable = nombre)
    ) |>
        purrr::list_rbind() |>
        dplyr::mutate(
            dimension = stringr::str_extract(
                variable,
                "^(emper|perper|comper|comgen)"
            )
        )

    tibble::tibble(
        categoria = rownames(mca$var$coord),
        dim1 = mca$var$coord[, 1],
        dim2 = mca$var$coord[, 2],
        cos2 = mca$var$cos2[, 1] + mca$var$cos2[, 2]
    ) |>
        dplyr::left_join(var_de_categoria, by = "categoria") |>
        dplyr::select(dimension, variable, categoria, dim1, dim2, cos2)
}

#' Centroide y contorno de cada cluster, para todas las soluciones
#'
#' Un scatter de 49.503 individuos queda sobreploteado y no se lee. Se resume en
#' lo que hay que mirar: dónde está el centro de cada grupo y cuánto se dispersa.
#'
#' @section Por qué el contorno es al 50% y no al 95%:
#' Al 95% las elipses se solapan casi por completo y el gráfico se vuelve
#' ilegible. El solapamiento es real —los clusters se forman en más dimensiones
#' que las dos que se grafican— pero las colas tapan justamente lo que hay que
#' leer, que es dónde está el núcleo de cada grupo.
#'
#' El contorno se construye desde la matriz de covarianza, así que su forma
#' refleja dispersión y correlación entre dimensiones, no es un círculo escalado.
#'
#' @param mca Objeto `MCA` (target `mca`).
#' @param hcpc Lista de objetos `HCPC` (target `hcpc`).
#' @param n_clases `cfg$N_CLASES`.
#' @param nivel Proporción de casos que encierra el contorno.
#' @return Una lista con dos tibbles, ambos con columna `solucion`:
#'   `centroides` (`cluster | dim1 | dim2 | casos`) y `elipses`
#'   (`cluster | orden | dim1 | dim2`).
datos_mapa_clusters <- function(mca, hcpc, n_clases, nivel = 0.50) {
    radio <- sqrt(stats::qchisq(nivel, df = 2))
    circulo <- seq(0, 2 * pi, length.out = 80)

    por_solucion <- purrr::map(n_clases, function(k) {
        h <- hcpc[[paste0("class", k)]]

        coord <- tibble::tibble(
            cluster = paste0("C", as.integer(h$data.clust$clust)),
            dim1 = mca$ind$coord[, 1],
            dim2 = mca$ind$coord[, 2]
        )

        centroides <- coord |>
            dplyr::summarise(
                dim1 = mean(dim1),
                dim2 = mean(dim2),
                casos = dplyr::n(),
                .by = cluster
            ) |>
            dplyr::mutate(solucion = k)

        elipses <- coord |>
            dplyr::group_split(cluster) |>
            purrr::map(function(g) {
                S <- stats::cov(cbind(g$dim1, g$dim2))
                mu <- c(mean(g$dim1), mean(g$dim2))
                pts <- t(
                    mu +
                        t(cbind(cos(circulo), sin(circulo)) %*% chol(S)) * radio
                )
                tibble::tibble(
                    solucion = k,
                    cluster = g$cluster[1],
                    orden = seq_along(circulo),
                    dim1 = pts[, 1],
                    dim2 = pts[, 2]
                )
            }) |>
            purrr::list_rbind()

        list(centroides = centroides, elipses = elipses)
    })

    list(
        centroides = purrr::map(por_solucion, "centroides") |>
            purrr::list_rbind() |>
            dplyr::arrange(solucion, cluster),
        elipses = purrr::map(por_solucion, "elipses") |>
            purrr::list_rbind() |>
            dplyr::arrange(solucion, cluster, orden)
    )
}

#' Matriz de perfiles: las categorías del modelo contra cada grupo
#'
#' Insumo del gráfico que reemplaza a la lectura por scroll de la tabla de
#' `v-test`. Una fila por categoría de las ocho variables del modelo, una
#' columna por grupo, y en la celda la diferencia en puntos porcentuales contra
#' el total (`lift_pp`).
#'
#' @section Por qué devuelve las dos bases juntas:
#' `lift_pp` existe calculado de dos maneras: [tabla_v_test()] lo saca de
#' `catdes()`, **sin ponderar**, y [tabla_lift_ponderado()] lo estima con el
#' **diseño muestral**. Ninguna reemplaza a la otra mientras la decisión esté
#' abierta, así que el target trae ambas con una columna `base` y la página las
#' presenta en un tabset. Cuando se cierre, se borra la que no quede.
#'
#' Se restringe a `cfg$VARS_MODELO` a propósito: la versión ponderada además
#' cubre las secundarias, pero `catdes()` no, y dos paneles con distinto
#' conjunto de filas no se podrían comparar, que es justamente para lo que está
#' el tabset.
#'
#' @section De dónde sale el orden de las filas:
#' De `datos_biplot_mca`, que trae las categorías en el orden de niveles con que
#' se ajustó el MCA y con su dimensión teórica. Ordenar así es lo que hace
#' visible el gradiente entre grupos: las tres soluciones altas no se separan
#' por intensidad sino por modalidad ("de día o de noche" contra "de día y de
#' noche"). La alternativa de ordenar por `lift_pp` se descartó porque el orden
#' cambiaría en cada columna y las filas dejarían de estar alineadas.
#'
#' @section Las celdas vacías:
#' `catdes()` devuelve solo las categorías que pasan su umbral de
#' significancia: en la solución de 5 son 115 de 120. La grilla se completa acá
#' para que el hueco llegue al gráfico como tal y se pueda dibujar distinto del
#' cero, en vez de faltar la fila. La base ponderada no tiene huecos.
#'
#' @param v_test Target `v_test_todas`.
#' @param lift_pond Target `lift_ponderado`.
#' @param biplot Target `datos_biplot_mca`.
#' @return Un tibble
#'   `base | solucion | grupo | dimension | variable | categoria | orden | pct_grupo | global_pct | lift_pp`.
datos_matriz_perfil <- function(v_test, lift_pond, biplot) {
    orden <- biplot |>
        dplyr::mutate(orden = dplyr::row_number()) |>
        dplyr::select(dimension, variable, categoria, orden)

    muestral <- v_test |>
        dplyr::transmute(
            base = "muestral",
            solucion,
            grupo = paste0("C", cluster),
            variable,
            categoria,
            pct_grupo = .data[["Mod/Cla"]],
            global_pct = Global,
            lift_pp
        ) |>
        #* El hueco de catdes() se hace explícito para que el gráfico lo pueda
        #* marcar. tidyr::complete() sobre grupo x categoría dentro de cada
        #* solución, no sobre el conjunto: cada solución tiene sus propios grupos.
        dplyr::group_by(solucion) |>
        dplyr::group_modify(\(d, ...) {
            tidyr::complete(d, grupo, tidyr::nesting(variable, categoria))
        }) |>
        dplyr::ungroup() |>
        dplyr::mutate(base = "muestral")

    ponderada <- lift_pond |>
        dplyr::filter(variable %in% unique(orden$variable)) |>
        dplyr::transmute(
            base = "ponderada",
            solucion,
            grupo,
            variable,
            categoria,
            pct_grupo,
            global_pct,
            lift_pp
        )

    res <- dplyr::bind_rows(muestral, ponderada) |>
        dplyr::inner_join(orden, by = c("variable", "categoria")) |>
        dplyr::relocate(dimension, .before = variable) |>
        dplyr::relocate(orden, .after = categoria) |>
        dplyr::arrange(base, solucion, grupo, orden)

    #* Las dos bases tienen que cubrir las mismas filas. Si una etiqueta cambia
    #* de un lado, el tabset mostraría dos matrices de distinto alto y la
    #* comparación dejaría de ser válida sin que nada falle.
    celdas <- res |>
        dplyr::count(base, solucion, name = "n_celdas") |>
        tidyr::pivot_wider(names_from = base, values_from = n_celdas)

    stopifnot(
        "datos_matriz_perfil(): las dos bases no cubren las mismas celdas" = isTRUE(
            all.equal(celdas$muestral, celdas$ponderada)
        )
    )

    res
}
