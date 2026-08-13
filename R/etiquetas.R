#' Especificación de etiquetas de los índices recodificados
#'
#' Reemplaza `processing/helpers/labels.R`. Target `spec_etiquetas_indices`,
#' aplicado al final de la recodificación (`2_recode.R:238-256`).
#'
#' @return Una lista con `variables` (vector nombrado etiqueta = variable) y
#'   `valores` (lista nombrada variable = vector nombrado etiqueta = código).
construir_spec_etiquetas_indices <- function() {
    list(
        variables = c(
            "Inseguridad en Espacio público" = "emper_ep_pct",
            "Inseguridad en espacio público (categorizada)" = "emper_ep_pct_cat",
            "Inseguridad en Barrio" = "emper_barrio_pct",
            "Inseguridad en el barrio (categorizada)" = "emper_barrio_pct_cat",
            "Inseguridad en Casa" = "emper_casa_pct",
            "Inseguridad en la casa (categorizada)" = "emper_casa_pct_cat",
            "Expectativa de ser victima delito" = "perper_delito",
            "Modifica comportamiento" = "comper_pct",
            "Modificación de prácticas (categorizada)" = "comper_pct_cat",
            "Gasta en medidas de seguridad" = "comper_gasto",
            "Dispone de medidas de seguridad (personales)" = "comgen_per_pct",
            "Medidas de seguridad de la vivienda (categorizada)" = "comgen_per_pct_cat",
            "Disponen de medidas de seguridad (comunitarias)" = "comgen_com_pct",
            "Medidas de seguridad del barrio (categorizada)" = "comgen_com_pct_cat"
        ),
        valores = list(
            "emper_ep_pct_cat" = c(
                "Sin inseguridad en espacio público" = 1,
                "Inseguridad en hasta la mitad de los lugares" = 2,
                "Inseguridad en más de la mitad de los lugares" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "emper_barrio_pct_cat" = c(
                "Sin inseguridad en el barrio" = 1,
                "Inseguridad en el barrio, de día o de noche" = 2,
                "Inseguridad en el barrio, de día y de noche" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "emper_casa_pct_cat" = c(
                "Sin inseguridad en la casa" = 1,
                "Inseguridad en la casa, de día o de noche" = 2,
                "Inseguridad en la casa, de día y de noche" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "perper_delito" = c(
                "No cree que será victima de delito" = 1,
                "Cree que será victima de delito no violento" = 2,
                "Cree que será victima de delito violento" = 3,
                "No sabe/No responde si cree que será victima de delito" = 4,
                "Cree que será victima de otro tipo de delito" = 5,
                "No sabe/No responde de qué delito será victima" = 6
            ),
            "comper_pct_cat" = c(
                "No modificó prácticas" = 1,
                "Modificó hasta la mitad de las prácticas" = 2,
                "Modificó más de la mitad de las prácticas" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "comper_gasto" = c(
                "Gasta en medidas de seguridad" = 1,
                "No gasta en medidas de seguridad" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "comgen_per_pct_cat" = c(
                "Sin medidas en la vivienda" = 1,
                "Una o dos medidas en la vivienda" = 2,
                "Tres o más medidas en la vivienda" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "comgen_com_pct_cat" = c(
                "Sin medidas en el barrio" = 1,
                "Una medida en el barrio" = 2,
                "Dos o más medidas en el barrio" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            )
        )
    )
}

#' Especificación de etiquetas de las variables secundarias
#'
#' Reemplaza los vectores embebidos en `4_add_vars.R:129-203`. Target
#' `spec_etiquetas_secundarias`, aplicado al final de `construir_vars_info()`
#' + `recodificar_sociodemograficas()`.
#'
#' @return Igual estructura que [construir_spec_etiquetas_indices()].
construir_spec_etiquetas_secundarias <- function() {
    list(
        variables = c(
            "Indice de desordenes" = "desordenes_ind",
            "Indice de desordenes (rec)" = "desordenes_ind_rec",
            "Indice de incivilidades" = "incivilidades_ind",
            "Indice de incivilidades (rec)" = "incivilidades_ind_rec",
            "Se informa por experiencia personal" = "info_exp_personal",
            "Se informa por otras personas" = "info_otras_personas",
            "Se informa por RRSS" = "info_rrss",
            "Se informa por prensa" = "info_prensa",
            "Se informa por TV" = "info_tv",
            "Nivel educacional (rec)" = "rph_nivel_rec",
            "Edad (rec)" = "rph_edad_rec",
            "Región (rec)" = "enc_region_rec"
        ),
        valores = list(
            "desordenes_ind_rec" = c(
                "Baja percepción de desordenes" = 1,
                "Media percepción de desordenes" = 2,
                "Alta percepción de desordenes" = 3
            ),
            "incivilidades_ind_rec" = c(
                "Baja percepción de incivilidades" = 1,
                "Media percepción de incivilidades" = 2,
                "Alta percepción de incivilidades" = 3
            ),
            "info_exp_personal" = c(
                "Se informa por experiencia personal" = 1,
                "No se informa por experiencia personal" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_otras_personas" = c(
                "Se informa por otras personas" = 1,
                "No se informa por otras personas" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_rrss" = c(
                "Se informa por RRSS" = 1,
                "No se informa por RRSS" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_prensa" = c(
                "Se informa por prensa" = 1,
                "No se informa por prensa" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_tv" = c(
                "Se informa por noticias" = 1,
                "No se informa por noticias" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "rph_nivel_rec" = c(
                "Educación básica o menos" = 1,
                "Educación secundaria" = 2,
                "Educación terciaria" = 3,
                "Sin dato" = 96,
                "Nivel ignorado" = 99
            ),
            "rph_edad_rec" = c(
                "0 a 29 años" = 1,
                "30 a 59 años" = 2,
                "60 años o más" = 3
            ),
            "enc_region_rec" = c(
                "Zona norte" = 1,
                "Zona centro" = 2,
                "Zona sur" = 3,
                "Zona metropolitana" = 4
            )
        )
    )
}

#' Aplicar etiquetas de variable y de valor
#'
#' Reemplaza `2_recode.R:238-256` y `4_add_vars.R:206-224`.
#'
#' @param datos Datos a etiquetar.
#' @param etiquetas Una especificación (`spec_etiquetas_indices` o
#'   `spec_etiquetas_secundarias`): lista con `variables` y `valores`.
#' @return `datos` con las etiquetas aplicadas.
etiquetar <- function(datos, etiquetas) {
    datos <- purrr::reduce2(
        unname(etiquetas$variables),
        names(etiquetas$variables),
        \(data, var, etiqueta) {
            data |>
                dplyr::mutate(
                    "{var}" := sjlabelled::set_label(
                        .data[[var]],
                        label = etiqueta
                    )
                )
        },
        .init = datos
    )

    purrr::reduce2(
        names(etiquetas$valores),
        etiquetas$valores,
        \(data, var, valores) {
            data |>
                dplyr::mutate(
                    "{var}" := sjlabelled::set_labels(
                        .data[[var]],
                        labels = valores
                    )
                )
        },
        .init = datos
    )
}
