# Insumos de los gráficos de la página (PLAN.md F5.4)
#
# Estas funciones NO dibujan: preparan los datos que el .qmd grafica. El corte
# es deliberado. Todo lo que sea cálculo —coordenadas, centroides, la matriz de
# covarianza de una elipse— vive acá, como target, y queda trazable. El dibujo
# es presentación y vive en el .qmd, donde se puede ajustar sin invalidar el DAG.
#
# Reemplazan a los gráficos por defecto de factoextra, que sirven para explorar
# pero no para comunicar: no distinguen dimensión teórica, superponen etiquetas
# y dibujan 49.503 puntos individuales donde solo se necesita leer dónde está el
# núcleo de cada grupo.

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
