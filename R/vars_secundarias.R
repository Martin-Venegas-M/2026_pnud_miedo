#' Índices de desórdenes e incivilidades
#'
#' Reemplaza `4_add_vars.R:35-58`. Vive acá D5: `88`/`99` se pasan a `NA` y se
#' suma con `rowSums(..., na.rm = TRUE)`, así que un ítem no respondido
#' desaparece del sumatorio en vez de invalidar el caso — "no sabe" se
#' comporta como "nunca ocurrió". Produce valores fuera del rango teórico de
#' la escala (mínimo real 8, pero los casos con todos los ítems en `88`/`99`
#' quedan en 0). No se corrige en esta fase (ver F1.0).
#'
#' @param datos Datos con `p_desordenes_*` y `p_incivilidades_*`.
#' @return `datos` con `desordenes_ind`, `desordenes_ind_rec`,
#'   `incivilidades_ind` e `incivilidades_ind_rec` agregadas.
construir_indices_secundarios <- function(datos) {
    datos <- datos |>
        dplyr::mutate(
            dplyr::across(
                dplyr::starts_with("p_desordenes_"),
                ~ dplyr::if_else(. %in% c(88, 99), NA, .),
                .names = "temp_{.col}"
            ),
            desordenes_ind = rowSums(
                dplyr::across(dplyr::starts_with("temp_")),
                na.rm = TRUE
            ),
            desordenes_ind_rec = dplyr::ntile(desordenes_ind, 3)
        ) |>
        dplyr::select(-dplyr::starts_with("temp_"))

    datos |>
        dplyr::mutate(
            dplyr::across(
                dplyr::starts_with("p_incivilidades_"),
                ~ dplyr::if_else(. %in% c(88, 99), NA, .),
                .names = "temp_{.col}"
            ),
            incivilidades_ind = rowSums(
                dplyr::across(dplyr::starts_with("temp_")),
                na.rm = TRUE
            ),
            incivilidades_ind_rec = dplyr::ntile(incivilidades_ind, 3)
        ) |>
        dplyr::select(-dplyr::starts_with("temp_"))
}

#' Variables de fuente de información
#'
#' Reemplaza `4_add_vars.R:60-102`.
#'
#' @param datos Datos con `p_fuente_info_barrio_1`, `p_fuente_info_com_1` y
#'   `p_fuente_info_pais_1`.
#' @return `datos` con `info_exp_personal`, `info_otras_personas`,
#'   `info_rrss`, `info_prensa` e `info_tv` agregadas.
construir_vars_info <- function(datos) {
    vec_info <- c(
        "p_fuente_info_barrio_1",
        "p_fuente_info_com_1",
        "p_fuente_info_pais_1"
    )

    datos <- datos |>
        dplyr::mutate(
            info_exp_personal = dplyr::if_else(
                dplyr::if_any(dplyr::all_of(vec_info), ~ . == 1),
                1,
                0
            ),
            info_otras_personas = dplyr::if_else(
                dplyr::if_any(dplyr::all_of(vec_info), ~ . %in% c(2:3)),
                1,
                0
            ),
            info_rrss = dplyr::if_else(
                dplyr::if_any(dplyr::all_of(vec_info), ~ . == 4),
                1,
                0
            ),
            info_prensa = dplyr::if_else(
                dplyr::if_any(dplyr::all_of(vec_info), ~ . %in% c(5:9)),
                1,
                0
            ),
            info_tv = dplyr::if_else(
                dplyr::if_any(dplyr::all_of(vec_info), ~ . == 5),
                1,
                0
            )
        )

    purrr::reduce(
        c(
            "info_exp_personal",
            "info_otras_personas",
            "info_rrss",
            "info_prensa",
            "info_tv"
        ),
        \(data, var) {
            data |>
                dplyr::mutate(
                    "{var}" := dplyr::case_when(
                        dplyr::if_all(dplyr::all_of(vec_info), ~ . == 88) ~
                            88,
                        dplyr::if_all(dplyr::all_of(vec_info), ~ . == 99) ~
                            99,
                        TRUE ~ .data[[var]]
                    )
                )
        },
        .init = datos
    )
}

#' Recodificar variables sociodemográficas
#'
#' Reemplaza `4_add_vars.R:104-125`.
#'
#' @param datos Datos con `rph_nivel`, `rph_edad` y `enc_region`.
#' @return `datos` con `rph_nivel_rec`, `rph_edad_rec` y `enc_region_rec`
#'   agregadas.
recodificar_sociodemograficas <- function(datos) {
    datos |>
        dplyr::mutate(
            rph_nivel_rec = dplyr::case_when(
                rph_nivel %in% 0:1 ~ 1,
                rph_nivel == 2 ~ 2,
                rph_nivel == 3 ~ 3,
                rph_nivel == 96 ~ 96,
                rph_nivel == 99 ~ 99
            ),
            rph_edad_rec = dplyr::case_when(
                rph_edad %in% 0:2 ~ 1,
                rph_edad %in% 3:5 ~ 2,
                rph_edad %in% 6:7 ~ 3
            ),
            enc_region_rec = dplyr::case_when(
                enc_region %in% c(15, 1:4) ~ 1,
                enc_region %in% c(5:9, 16) ~ 2,
                enc_region %in% c(10:12, 14) ~ 3,
                enc_region %in% c(13) ~ 4,
            )
        )
}

#' Magnitud de la no-respuesta en los índices secundarios
#'
#' Mide el efecto de la convención vigente en `construir_indices_secundarios()`:
#' los ítems en `88`/`99` se pasan a `NA` y `rowSums(na.rm = TRUE)` los descarta
#' del sumatorio, de modo que la no-respuesta se comporta como si el desorden
#' nunca hubiera ocurrido.
#'
#' El indicador que importa es `min_teorico` contra `min_observado`: con ítems en
#' escala de 1 a 5, el mínimo que puede producir cualquier combinación de
#' respuestas válidas es el número de ítems. Un índice por debajo de eso no
#' corresponde a ninguna respuesta posible — es el rastro de la no-respuesta.
#'
#' Existe porque la página necesita mostrar la magnitud del problema y ningún
#' número de la página puede nacer en un chunk (PLAN.md F5.4). Ver D5.
#'
#' @param datos `datos_finales`.
#' @return Un tibble con una fila por índice.
medir_no_respuesta_indices <- function(datos) {
    especificacion <- list(
        list(
            indice = "desordenes_ind",
            etiqueta = "Percepción de desórdenes",
            prefijo = "p_desordenes_"
        ),
        list(
            indice = "incivilidades_ind",
            etiqueta = "Percepción de incivilidades",
            prefijo = "p_incivilidades_"
        )
    )

    purrr::map(especificacion, function(e) {
        items <- grep(paste0("^", e$prefijo), names(datos), value = TRUE)
        M <- vapply(datos[items], haven::zap_labels, numeric(nrow(datos)))
        no_respuesta <- matrix(M %in% c(88, 99), nrow = nrow(M))
        n_nr <- rowSums(no_respuesta)
        valores <- datos[[e$indice]]

        tibble::tibble(
            indice = e$etiqueta,
            n_items = length(items),
            #* Con ítems de 1 a 5, ninguna combinación válida baja del número
            #* de ítems: ese es el piso real de la escala.
            min_teorico = length(items),
            casos_alguna_nr = sum(n_nr > 0),
            pct_alguna_nr = round(100 * mean(n_nr > 0), 1),
            casos_toda_nr = sum(n_nr == length(items)),
            valor_si_toda_nr = unique(valores[n_nr == length(items)])[1],
            min_observado = min(valores, na.rm = TRUE),
            max_observado = max(valores, na.rm = TRUE)
        )
    }) |>
        purrr::list_rbind()
}
