#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Recodificación
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Este script contiene el código para añadir
#*******************************************************************************

rm(list = ls())

# 1. Cargar paquetes -----------------------------------------------------------
purrr::walk(
    c(
        "tidyverse",
        "haven",
        "tidylog",
        "rlang",
        "sjlabelled",
        "sjmisc",
        "sjPlot",
        "glue"
    ),
    \(pkg) library(pkg, character.only = TRUE)
)

# 2. Cargar datos y funciones --------------------------------------------------
source("tipologias/config.R", encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "validate.R"), encoding = "UTF-8")

enusc <- readRDS(cfg$FILE_ENUSC_RECODE)

#* ! IMPORTANTE: este script depende del .RData que produce analysis/mca_hcpc.R,
#* por lo que el MCA debe correr ANTES. Ver el orden real en
#* tipologias/run_all.R. Correr en el orden que sugeria el antiguo
#* run_processing.R (1 -> 2 -> 3) con datos de otra ola pega los clusters de la
#* ola anterior.
if (!file.exists(cfg$FILE_MCA_HCPC)) {
    stop(glue::glue(
        "Falta {cfg$FILE_MCA_HCPC}. Correr analysis/mca_hcpc.R antes que este script."
    ))
}
load(cfg$FILE_MCA_HCPC)

#* Que el archivo exista no basta: si quedó en disco el .RData de la ola
#* anterior, file.exists() pasa igual y el left_join() de más abajo pegaría
#* clusters de otra ola sobre estos datos.
validar_huella_modelo(enusc, if (exists("huella_input")) huella_input else NULL)

# 3. Ejecutar código -----------------------------------------------------------

# 3.1 Añadir variables de cluster ----------------------------------------------

# Añadir variables de cluster
add_clust <- function(data, nclust) {
    df_clust <- results_all[[glue("class{nclust}")]]$data %>%
        select(all_of(c("rph_id", glue("clusters_{nclust}"))))

    #* Nombres sustantivos solo para la solución reportada (cfg$CLUSTER_A_SACAR)
    #* en 2024. Las soluciones exploratorias y la ola 2025 -- que todavía no
    #* tiene nombre -- se quedan con la etiqueta genérica. Ver cfg$ETIQ_CLUSTER_2024
    #* en config.R.
    etiquetas_clust <- if (
        cfg$ANIO == 2024 && glue("clusters_{nclust}") == cfg$CLUSTER_A_SACAR
    ) {
        unname(cfg$ETIQ_CLUSTER_2024[paste0("Cluster ", 1:nclust)])
    } else {
        paste0("Cluster ", 1:nclust)
    }

    data <- data %>%
        left_join(df_clust) %>%
        mutate(across(
            glue("clusters_{nclust}"),
            ~ factor(
                .,
                levels = c(1:nclust),
                labels = etiquetas_clust
            )
        ))

    return(data)
}

# Iterar!
enusc <- reduce(
    rev(cfg$N_CLASES),
    \(data, nclust) add_clust(data, nclust),
    .init = enusc
)

# 3.2 Crear indices de desordenes e incivilidades ------------------------------

# Crear indice desordenes
enusc <- enusc %>%
    mutate(
        across(
            starts_with("p_desordenes_"),
            ~ if_else(. %in% c(88, 99), NA, .),
            .names = "temp_{.col}"
        ),
        desordenes_ind = rowSums(across(starts_with("temp_")), na.rm = TRUE),
        desordenes_ind_rec = ntile(desordenes_ind, 3)
    ) %>%
    select(-starts_with("temp_"))

# Crear indice incivilidades
enusc <- enusc %>%
    mutate(
        across(
            starts_with("p_incivilidades_"),
            ~ if_else(. %in% c(88, 99), NA, .),
            .names = "temp_{.col}"
        ),
        incivilidades_ind = rowSums(across(starts_with("temp_")), na.rm = TRUE),
        incivilidades_ind_rec = ntile(incivilidades_ind, 3)
    ) %>%
    select(-starts_with("temp_"))

# 3.3 Crear variables de información -------------------------------------------
vec_info <- c(
    "p_fuente_info_barrio_1",
    "p_fuente_info_com_1",
    "p_fuente_info_pais_1"
) # Variables fuente

# Crear!
enusc <- enusc %>%
    mutate(
        info_exp_personal = if_else(if_any(all_of(vec_info), ~ . == 1), 1, 0),
        info_otras_personas = if_else(
            if_any(all_of(vec_info), ~ . %in% c(2:3)),
            1,
            0
        ),
        info_rrss = if_else(if_any(all_of(vec_info), ~ . == 4), 1, 0),
        info_prensa = if_else(if_any(all_of(vec_info), ~ . %in% c(5:9)), 1, 0),
        info_tv = if_else(if_any(all_of(vec_info), ~ . == 5), 1, 0)
    )

# Manejo explicito de Otros, No sabe y no responde!
enusc <- reduce(
    c(
        "info_exp_personal",
        "info_otras_personas",
        "info_rrss",
        "info_prensa",
        "info_tv"
    ),
    \(data, var) {
        data %>%
            mutate(
                "{var}" := case_when(
                    # if_all(all_of(vec_info), ~ . == 77) ~ 77, #! El otro quedará dentro de la categoría 0!
                    if_all(all_of(vec_info), ~ . == 88) ~ 88,
                    if_all(all_of(vec_info), ~ . == 99) ~ 99,
                    TRUE ~ .data[[var]]
                )
            )
    },
    .init = enusc
)

# 3.4 Recodificar variables sociodemográficas ----------------------------------
enusc <- enusc %>%
    mutate(
        rph_nivel_rec = case_when(
            rph_nivel %in% 0:1 ~ 1,
            rph_nivel == 2 ~ 2,
            rph_nivel == 3 ~ 3,
            rph_nivel == 96 ~ 96,
            rph_nivel == 99 ~ 99
        ),
        rph_edad_rec = case_when(
            rph_edad %in% 0:2 ~ 1,
            rph_edad %in% 3:5 ~ 2,
            rph_edad %in% 6:7 ~ 3
        ),
        enc_region_rec = case_when(
            enc_region %in% c(15, 1:4) ~ 1,
            enc_region %in% c(5:9, 16) ~ 2,
            enc_region %in% c(10:12, 14) ~ 3,
            enc_region %in% c(13) ~ 4,
        )
    )

# 3.4 Etiquetar ----------------------------------------------------------------

etiquetas_variables <- c(
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
)

etiquetas_valores <- list(
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

# Aplicar etiquetas variables
enusc <- reduce2(
    unname(etiquetas_variables),
    names(etiquetas_variables),
    \(data, var, etiqueta) {
        data %>%
            mutate("{var}" := set_label(.data[[var]], label = etiqueta))
    },
    .init = enusc
)

# Aplicar etiquetas valores
enusc <- reduce2(
    names(etiquetas_valores),
    etiquetas_valores,
    \(data, var, etiquetas) {
        data %>% mutate("{var}" := set_labels(.data[[var]], labels = etiquetas))
    },
    .init = enusc
)

# 4. Guardar bbdd --------------------------------------------------------------
saveRDS(enusc, cfg$FILE_ENUSC_ADDVARS)
