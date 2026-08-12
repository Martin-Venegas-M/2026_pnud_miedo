#' Preparar los datos de entrada al MCA
#'
#' Reemplaza `3_add_clust.R:46-75`. Pasa `85`/`88`/`99` a `NA` en toda columna
#' que matchee `emper|perper|pergen|comper|comgen`, se queda solo con
#' `rph_id` y `vars`, saca a `NA` las categorías 4 y 6 de `perper_delito`
#' (no sabe/no responde, en sus dos formas) y convierte todo a factor con las
#' etiquetas ya aplicadas por `etiquetar()`.
#'
#' **D3 aplicada** (PLAN.md): antes se excluían las categorías `c(4, 5)`, con
#' la 5 mezclando "otro delito" (sustantivo) y no-respuesta.
#' `construir_perper_delito()` separó esa mezcla en 5 (otro delito) y 6 (no
#' sabe/no responde); acá se ajustó el filtro a `c(4, 6)` para conservar la 5
#' en el modelo.
#'
#' @param datos Datos recodificados y etiquetados (`datos_recodificados`).
#' @param vars Variables que entran al MCA (`cfg$VARS_MODELO`).
#' @return Un data frame `rph_id` + `vars`, factores, sin filtrar por `NA`
#'   todavía — eso lo hace [filtrar_casos_completos()].
preparar_datos_mca <- function(datos, vars) {
    datos <- purrr::reduce(
        c(85, 88, 99),
        \(data, code) {
            message(glue::glue(
                "Removiendo el código {code} para las siguientes varables:"
            ))
            data |>
                dplyr::mutate(dplyr::across(
                    dplyr::matches("emper|perper|pergen|comper|comgen"),
                    ~ replace(., which(. %in% code), NA)
                ))
        },
        .init = datos
    )

    datos |>
        dplyr::select(rph_id, dplyr::all_of(vars)) |>
        dplyr::mutate(
            dplyr::across(perper_delito, ~ replace(., which(. %in% c(4, 6)), NA)),
            dplyr::across(dplyr::all_of(vars), ~ sjlabelled::to_label(.))
        )
}

#' Filtrar los casos completos que entran al MCA
#'
#' Reemplaza `3_add_clust.R:80`. Solo filtra — no reporta (regla #7: el log
#' es un target derivado, pareado, no un efecto secundario de esta función;
#' ver [reportar_perdida()]).
#'
#' @param datos Salida de [preparar_datos_mca()].
#' @param vars Variables que deben estar completas.
#' @return `datos` sin los casos con `NA` en alguna de `vars`.
filtrar_casos_completos <- function(datos, vars) {
    datos |> tidyr::drop_na(dplyr::all_of(vars))
}

#' Ajustar el MCA
#'
#' Reemplaza la parte de `mca_hcpc()` (`functions.R:358`) que corre
#' `FactoMineR::MCA()`. Antes se recalculaba una vez por solución de cluster
#' (`cfg$N_CLASES = 6:4`) pese a no depender de `n_class`; acá es un target
#' que corre una sola vez.
#'
#' @param datos Casos completos, factores (salida de
#'   [filtrar_casos_completos()]).
#' @param id_col Columna identificadora, como string. Se excluye del modelo.
#' @return El objeto `MCA` de FactoMineR.
ajustar_mca <- function(datos, id_col = "rph_id") {
    FactoMineR::MCA(
        datos |> dplyr::select(-dplyr::all_of(id_col)),
        graph = FALSE
    )
}

#' Ajustar el HCPC sobre un MCA ya calculado
#'
#' Reemplaza la parte de `mca_hcpc()` que corre `FactoMineR::HCPC()`.
#' `consol = FALSE` es lo que hace el resultado determinista (no depende de
#' semilla); verificado contra el gold del repo viejo caso por caso.
#'
#' @param mca Objeto MCA de [ajustar_mca()].
#' @param n_clases Número de clases a extraer del árbol jerárquico.
#' @return El objeto `HCPC` de FactoMineR.
ajustar_hcpc <- function(mca, n_clases) {
    FactoMineR::HCPC(
        mca,
        nb.clust = n_clases,
        consol = FALSE,
        graph = FALSE
    )
}

#' Ejecutar el HCPC para cada número de clases pedido
#'
#' @param mca Objeto MCA de [ajustar_mca()].
#' @param n_clases Vector de números de clases (`cfg$N_CLASES`).
#' @return Una lista nombrada `class{n}`, un elemento por solución.
ajustar_hcpc_todos <- function(mca, n_clases) {
    resultado <- purrr::map(n_clases, function(n) {
        h <- ajustar_hcpc(mca, n)
        gc()
        h
    })
    purrr::set_names(resultado, paste0("class", n_clases))
}

#' Extraer la asignación de cluster de cada solución
#'
#' Target `soluciones`. Reemplaza el `data.clust$clust` que `mca_hcpc()`
#' guardaba en `results_all[[...]]$data`.
#'
#' @param datos Casos completos usados en el MCA (para el `rph_id` de cada
#'   fila, en el mismo orden que las asignaciones de `hcpc`).
#' @param hcpc Lista de objetos `HCPC`, salida de [ajustar_hcpc_todos()].
#' @param n_clases Vector de números de clases (`cfg$N_CLASES`).
#' @return Una lista nombrada `class{n}`, cada elemento con `n` (el número de
#'   clases) y `tabla` (`rph_id` + `cluster`, la asignación cruda del HCPC).
construir_soluciones <- function(datos, hcpc, n_clases) {
    purrr::map(n_clases, function(n) {
        h <- hcpc[[paste0("class", n)]]
        list(
            n = n,
            tabla = tibble::tibble(
                rph_id = datos$rph_id,
                cluster = h$data.clust$clust
            )
        )
    }) |>
        purrr::set_names(paste0("class", n_clases))
}

#' Pegar las soluciones de cluster a la base
#'
#' Reemplaza `3_add_clust.R:89-113` (`add_clust()` + el `reduce()` que lo
#' itera). Un `left_join` por solución más el `factor()` con etiquetas
#' `C1..Cn`.
#'
#' @param datos Base a la que pegar los clusters (`datos_recodificados`, NO
#'   la de entrada al MCA: se pega sobre todos los casos, y quedan `NA` los
#'   que el MCA no pudo asignar).
#' @param soluciones Salida de [construir_soluciones()].
#' @return `datos` con una columna `clusters_{n}` por solución, como factor.
pegar_clusters <- function(datos, soluciones) {
    purrr::reduce(
        rev(soluciones),
        function(data, sol) {
            nombre_col <- paste0("clusters_", sol$n)
            tabla <- sol$tabla |> dplyr::rename("{nombre_col}" := cluster)
            data |>
                dplyr::left_join(tabla, by = "rph_id") |>
                dplyr::mutate(dplyr::across(
                    dplyr::all_of(nombre_col),
                    ~ factor(
                        .,
                        levels = 1:sol$n,
                        labels = paste0("C", 1:sol$n)
                    )
                ))
        },
        .init = datos
    )
}
