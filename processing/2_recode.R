#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Recodificación
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Este script contiene el código para la recodificación de
# las variables principales
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
        "glue",
        "openxlsx"
    ),
    \(pkg) library(pkg, character.only = TRUE)
)

# 2. Cargar datos y funciones --------------------------------------------------

source("config.R", encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "functions.R"), encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "labels.R"), encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "dic_items.R"), encoding = "UTF-8")

enusc <- readRDS(cfg$FILE_ENUSC_SELECT)

# 3. Ejecutar código -----------------------------------------------------------

# 3.1 Crear insumo -------------------------------------------------------------
#* NOTA: Este insumo contiene los vectores de variables que se utilizan en la
#* creación de las variables recodificadas
rec_vars <- list(
    emper_ep_pct = c(paste0("emper_p_inseg_lugares_", 1:11)),
    emper_barrio_pct = c("emper_p_inseg_oscuro_1", "emper_p_inseg_dia_1"), # Caminando por el barrio día y noche
    emper_casa_pct = c("emper_p_inseg_oscuro_2", "emper_p_inseg_dia_2"), # Estando en su casa día y noche
    perper_delito = list(
        "perper_p_expos_delito",
        paste0("perper_p_delito_pronostico_", c(1:4, 6, 9:11)),
        paste0("perper_p_delito_pronostico_", c(5, 7:8)),
        "perper_p_expos_delito",
        paste0("perper_p_delito_pronostico_", c(77, 88, 99))
    ),
    comper_pct = paste0("comper_p_mod_actividades_", 1:13),
    comper_gasto = c("comper_costos_medidas"),
    comgen_per_pct = c(
        "comgen_medidas_perro",
        "comgen_medidas_alarma_privada",
        "comgen_medidas_camaras_vigilancia",
        "comgen_medidas_rejas",
        "comgen_medidas_cerco",
        "comgen_medidas_proteccion",
        "comgen_medidas_seguro",
        "comgen_medidas_foco",
        "comgen_medidas_otro",
        "comgen_medidas_na"
    ), # Todas las medidas personales
    comgen_com_pct = c(
        "comgen_vecinos_medidas_whatsapp",
        "comgen_vecinos_medidas_vigilancia",
        "comgen_vecinos_medidas_al_comunit",
        "comgen_vecinos_medidas_coord_pol",
        "comgen_vecinos_medidas_coord_mun",
        "comgen_vecinos_medidas_televig",
        "comgen_vecinos_medidas_privad",
        "comgen_vecinos_medidas_otro",
        "comgen_vecinos_medidas_na"
    ) # Todas las medidas comunitarias
)

# 3.2 Recodificar --------------------------------------------------------------
enusc <- enusc |>
    create_var_pct(
        success.cats = c(1, 2),
        source.cols = rec_vars[["emper_ep_pct"]],
        name.var.pct = "emper_ep_pct"
    ) |>
    create_var_pct(
        success.cats = c(1, 2),
        source.cols = rec_vars[["emper_barrio_pct"]],
        name.var.pct = "emper_barrio_pct"
    ) |>
    create_var_pct(
        success.cats = c(1, 2),
        source.cols = rec_vars[["emper_casa_pct"]],
        name.var.pct = "emper_casa_pct"
    ) |>
    mutate(
        perper_delito = case_when(
            if_all(rec_vars[["perper_delito"]][[1]], ~ . == 2) ~ 1, # No cree que será victima de delito
            if_any(rec_vars[["perper_delito"]][[2]], ~ . == 1) ~ 2, # Cree que será victima de un delito no violento
            if_any(rec_vars[["perper_delito"]][[3]], ~ . == 1) ~ 3, # Cree que será victima de un delito violento
            if_all(rec_vars[["perper_delito"]][[4]], ~ . %in% c(88, 99)) ~ 4, # No sabe/No responde si cree que será victima de delito
            if_any(rec_vars[["perper_delito"]][[5]], ~ . == 1) ~ 5, # No sabe/No responde de qué delito será victima / Cree que será victima de otro tipo de delito
            TRUE ~ NA
        ),
    ) |>
    create_var_pct(
        success.cats = 1,
        source.cols = rec_vars[["comper_pct"]],
        name.var.pct = "comper_pct"
    ) |>
    mutate(
        comper_gasto = case_when(
            if_all(rec_vars[["comper_gasto"]], ~ . %in% c(1:5)) ~ 1,
            if_all(rec_vars[["comper_gasto"]], ~ . == 85) ~ 0,
            if_all(rec_vars[["comper_gasto"]], ~ . == 88) ~ 88,
            if_all(rec_vars[["comper_gasto"]], ~ . == 99) ~ 99,
            TRUE ~ NA
        )
    ) |>
    create_var_pct(
        success.cats = 1,
        source.cols = rec_vars[["comgen_per_pct"]],
        name.var.pct = "comgen_per_pct"
    ) |>
    create_var_pct(
        success.cats = 1,
        source.cols = rec_vars[["comgen_com_pct"]],
        name.var.pct = "comgen_com_pct"
    )

# Ver!

sjmisc::frq(enusc$emper_ep_pct) #* Hay varianza, 171 NA's
sjmisc::frq(enusc$emper_barrio_pct) #* 3 categorías (0, 50, 100), 1015 NA's
sjmisc::frq(enusc$emper_casa_pct) #* 3 categorías (0, 50, 100), 106 NA's
sjmisc::frq(enusc$perper_delito) #* 5 categorías (1:5), bien, no NA's
sjmisc::frq(enusc$comper_pct) #* Hay varianza, 37 NA's
sjmisc::frq(enusc$comper_gasto) #* 4 categorías (0, 1, 88, 99), 1 NA
sjmisc::frq(enusc$comgen_per_pct) #* Hay varianza, 0 NA's
sjmisc::frq(enusc$comgen_com_pct) #* Hay varianza, 0 NA's

# 3.3 Crear variabls "rec_tercil" e imputar 88 y 99 en variables comgen -------

vec_comgen_per <- c(
    "comgen_medidas_ns",
    "comgen_medidas_nr"
)
vec_comgen_com <- c(
    "comgen_vecinos_medidas_ns",
    "comgen_vecinos_medidas_nr"
)

enusc <- enusc |>
    mutate(
        # Pasar a NA las variables de comgen cuando se selecciona la columna de
        # No sabe o No responde
        comgen_per_pct = if_else(
            if_any(all_of(vec_comgen_per), ~ . == 1),
            NA,
            comgen_per_pct
        ),
        comgen_com_pct = if_else(
            if_any(all_of(vec_comgen_com), ~ . == 1),
            NA,
            comgen_com_pct
        ),
        # ! IMPORTANTE: CREAR VARIABLE TERCILES, ESTA USAMOS PARA LOS ANÁLISIS
        across(ends_with("_pct"), ~ ntile(., 3), .names = "{.col}_rec_tercil"),
        # Manejo explicito de No sabe y No responde para variables de
        # comgen (es necesario ya que son preguntas de opción múltiple)
        comgen_per_pct_rec_tercil = case_when(
            comgen_medidas_ns == 1 ~ 88,
            comgen_medidas_nr == 1 ~ 99,
            TRUE ~ comgen_per_pct_rec_tercil
        ),
        comgen_com_pct_rec_tercil = case_when(
            comgen_vecinos_medidas_ns == 1 ~ 88,
            comgen_vecinos_medidas_nr == 1 ~ 99,
            TRUE ~ comgen_com_pct_rec_tercil
        )
    )

# Ver!
sjmisc::frq(enusc$emper_ep_pct_rec_tercil) #* Se mantienen 171 NA's
sjmisc::frq(enusc$emper_barrio_pct_rec_tercil) #* Se mantienen 1015 NA's
sjmisc::frq(enusc$emper_casa_pct_rec_tercil) #* Se mantienen 106 NA's
sjmisc::frq(enusc$perper_delito) #* Se mantiene la no existencia de NA's
sjmisc::frq(enusc$comper_pct_rec_tercil) #* Se mantienen 37 NA's
sjmisc::frq(enusc$comper_gasto) #* Se mantiene 1 NA
sjmisc::frq(enusc$comgen_per_pct_rec_tercil) #* Se mantienen 0 NA's, ahora hay 88 y 99
sjmisc::frq(enusc$comgen_com_pct_rec_tercil) #* Se mantienen 0 NA's, ahora hay 88 y 99

# 3.4 Recuperar 85, 88 y 99 en variables de opción única ----------------------

# Excluir variables de la imputación
excluir <- c("perper_delito", "comper_gasto")
rec_vars_torec <- rec_vars[!names(rec_vars) %in% excluir]

# Agregar sufijjo "_rec_tercil" a los nombres de las variables
names(rec_vars_torec) <- if_else(
    str_detect(names(rec_vars_torec), "_pct$"),
    paste0(names(rec_vars_torec), "_rec_tercil"),
    names(rec_vars_torec)
)

# Imputar!
enusc <- reduce2(
    names(rec_vars_torec),
    rec_vars_torec,
    \(data, rec_var, dim_vars) {
        data |>
            mutate(
                "{rec_var}" := case_when(
                    if_all(all_of(dim_vars), ~ . == 85) ~ 85,
                    if_all(all_of(dim_vars), ~ . == 88) ~ 88,
                    if_all(all_of(dim_vars), ~ . == 99) ~ 99,
                    TRUE ~ .data[[rec_var]]
                )
            )
    },
    .init = enusc
)

# Ver!
sjmisc::frq(enusc$emper_ep_pct_rec_tercil) #* 85 y 99 recuperads
sjmisc::frq(enusc$emper_barrio_pct_rec_tercil) #* 85, 88 y 99 recuperados
sjmisc::frq(enusc$emper_casa_pct_rec_tercil) #* 85, 88 y 99 recuperados
sjmisc::frq(enusc$perper_delito) #* Sigue igual, sin NA
sjmisc::frq(enusc$comper_pct_rec_tercil) #* 85 y 99 recuperados
sjmisc::frq(enusc$comper_gasto) #! Quedó un NA
sjmisc::frq(enusc$comgen_per_pct_rec_tercil) #* Se mantienen los 88 y 99
sjmisc::frq(enusc$comgen_com_pct_rec_tercil) #* Se mantienen los 88 y 99

# 3.5 Etiquetar ----------------------------------------------------------------

# Aplicar etiquetas variables
enusc <- reduce2(
    unname(etiquetas_variables),
    names(etiquetas_variables),
    \(data, var, etiqueta) {
        data |>
            mutate("{var}" := set_label(.data[[var]], label = etiqueta))
    },
    .init = enusc
)

# Aplicar etiquetas valores
enusc <- reduce2(
    names(etiquetas_valores),
    etiquetas_valores,
    \(data, var, etiquetas) {
        data |> mutate("{var}" := set_labels(.data[[var]], labels = etiquetas))
    },
    .init = enusc
)

# 4. Guardar bbdd --------------------------------------------------------------
saveRDS(enusc, cfg$FILE_ENUSC_RECODE)
