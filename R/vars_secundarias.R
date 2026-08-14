#' Índices de desórdenes e incivilidades
#'
#' Cada índice es la **suma** de una batería de ítems en escala de 1 a 5, así
#' que mide intensidad: distingue a quien responde "nunca" a todo de quien
#' responde "ocasionalmente" a todo. Se conserva esa métrica.
#'
#' @section Qué reemplaza y por qué:
#' Antes los ítems en `88`/`99` se pasaban a `NA` y se sumaba con
#' `rowSums(na.rm = TRUE)`, de modo que un ítem no respondido desaparecía del
#' sumatorio en vez de invalidar el caso: "no sabe" se comportaba como "nunca
#' ocurrió". El índice caía por debajo de su piso teórico (mínimo 8 con ocho
#' ítems de 1 a 5) y quien no respondía nada quedaba en 0, por debajo de quien
#' respondía "nunca" a todo.
#'
#' Afectaba a 6.563 casos en desórdenes (11,8%) y 1.839 en incivilidades
#' (3,3%), con un sesgo sistemático hacia abajo de unos 3 puntos entre los
#' afectados.
#'
#' @section Por qué prorratear y no imputar con hot deck:
#' En siete de cada diez casos afectados falta **un ítem de ocho**, en una
#' batería donde todos miden lo mismo. El mejor predictor del ítem faltante son
#' las otras respuestas de la misma persona, no las de un donante parecido. El
#' prorrateo (media de los ítems válidos por el número de ítems) es el
#' procedimiento estándar para puntajes de escala, es determinista y no exige
#' definir celdas de ajuste.
#'
#' El argumento habitual a favor del hot deck —que la imputación por media
#' encoge la varianza— no aplica acá: la desviación estándar sube levemente
#' (6,87 a 7,11 en desórdenes), porque desaparecen los valores fuera de escala.
#'
#' @param datos Datos con `p_desordenes_*` y `p_incivilidades_*`.
#' @param min_validos Proporción mínima de ítems respondidos para prorratear.
#'   Por debajo de eso el índice queda `NA`: prorratear con uno o dos ítems de
#'   ocho es forzar demasiado.
#' @return `datos` con `desordenes_ind`, `desordenes_ind_rec`,
#'   `incivilidades_ind` e `incivilidades_ind_rec` agregadas.
construir_indices_secundarios <- function(datos, min_validos = 0.5) {
    prorratear <- function(datos, prefijo, nombre) {
        items <- grep(paste0("^", prefijo), names(datos), value = TRUE)
        if (length(items) == 0) {
            rlang::abort(paste0("No hay ítems con el prefijo '", prefijo, "'."))
        }

        M <- datos[items] |>
            purrr::map(\(x) as.numeric(haven::zap_labels(x))) |>
            as.data.frame() |>
            as.matrix()
        M[M %in% c(88, 96, 99)] <- NA_real_

        n_validos <- rowSums(!is.na(M))
        suficientes <- n_validos >= ceiling(min_validos * length(items))

        #* media de lo respondido x número de ítems: conserva la escala de la
        #* suma y no puede salirse de su rango.
        indice <- rowMeans(M, na.rm = TRUE) * length(items)
        indice[!suficientes] <- NA_real_

        #* Los terciles se cortan en los mismos umbrales que daría ntile(),
        #* pero asignando por VALOR y no por rango. ntile() reparte los empates
        #* entre categorías para forzar grupos iguales: acá partía a 2.234
        #* personas con índice 13 entre el tercil 1 y el 2. Los grupos quedan
        #* desiguales
        #* (37/30/33), que es lo correcto cuando la variable tiene empates.
        cortes <- stats::quantile(indice, c(1 / 3, 2 / 3), na.rm = TRUE)

        datos[[nombre]] <- indice
        datos[[paste0(nombre, "_rec")]] <- cut(
            indice,
            breaks = c(-Inf, cortes, Inf),
            labels = FALSE
        )
        datos
    }

    datos |>
        prorratear("p_desordenes_", "desordenes_ind") |>
        prorratear("p_incivilidades_", "incivilidades_ind")
}

#' Variables de fuente de información
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
#' Existe como target porque la página necesita mostrar la magnitud del problema
#' y ningún número de la página puede nacer en un chunk.
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
        M <- datos[items] |>
            purrr::map(\(x) as.numeric(haven::zap_labels(x))) |>
            as.data.frame() |>
            as.matrix()
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
