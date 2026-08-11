#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Configuración del pipeline de tipologías
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Configuración del pipeline: rutas, vectores de
# variables, solución de cluster a reportar y parámetros de
# la ola.
#*******************************************************************************

# 1. Ola / parámetros de corrida -----------------------------------------------

ANIO_DEFECTO <- 2025

cfg <- list(
    ANIO = ANIO_DEFECTO,
    DATE = format(Sys.Date(), "%y%m%d"), # Prefijo de fecha para los outputs
    USER = tolower(Sys.info()["user"]),
    CLUSTER_A_SACAR = "clusters_5",
    N_CLASES = 6:4
)

# ! PENDIENTE: TENEMOS QUE VER QUE SOLUCIÓN USAREMOS PARA EL ANÁLISIS
# cfg$ETIQ_CLUSTER <- c(
#     "Cluster 1" = "C1:",
#     "Cluster 2" = "C2:",
#     "Cluster 3" = "C3:",
#     "Cluster 4" = "C4:",
#     "Cluster 5" = "C5:"
# )

# 2. Rutas ---------------------------------------------------------------------

cfg$PATH_ORIGINAL <- "input/data/original"
cfg$PATH_HELPERS <- "processing/helpers"
cfg$PATH_HELPERS_AN <- "analysis/helpers"

cfg$PATH_PROC <- file.path("input/data/proc", cfg$ANIO)
cfg$PATH_TABLES <- file.path("output/tables", cfg$ANIO)
cfg$PATH_MODELS <- file.path("output/models", cfg$ANIO)

#* Se crean acá para que los scripts no fallen al escribir en una ola nueva.
purrr::walk(
    c(cfg$PATH_PROC, cfg$PATH_TABLES, cfg$PATH_MODELS),
    \(p) dir.create(p, recursive = TRUE, showWarnings = FALSE)
)

cfg$FILE_ENUSC_ORIGINAL <- file.path(
    cfg$PATH_ORIGINAL,
    paste0("base-de-datos---enusc-", cfg$ANIO, ".RDS")
)
cfg$FILE_ENUSC_SELECT <- file.path(cfg$PATH_PROC, "enusc_1_select.RDS")
cfg$FILE_ENUSC_RECODE <- file.path(cfg$PATH_PROC, "enusc_2_recode.RDS")
cfg$FILE_ENUSC_ADDCLUST <- file.path(cfg$PATH_PROC, "enusc_3_add_clust.RDS")
cfg$FILE_ENUSC_ADDVARS <- file.path(cfg$PATH_MODELS, "enusc_4_add_vars.RDS")

cfg$FILE_METADATA <- file.path(cfg$PATH_TABLES, "metadata_recode.xlsx")

# 3. Diseño muestral -----------------------------------------------------------
cfg$SVY_IDS <- "conglomerado"
cfg$SVY_STRATA <- "varstrat"
cfg$SVY_WEIGHTS <- "fact_pers_reg"

# 4. Vectores de variables -----------------------------------------------------

# 4.1 Recodificadas con las "_pct" en terciles ---------------------------------
cfg$VARS_REC_TERCIL <- c(
    "emper_ep_pct_rec_tercil",
    "emper_barrio_pct_rec_tercil",
    "emper_casa_pct_rec_tercil",
    "perper_delito",
    "comper_pct_rec_tercil",
    "comper_gasto",
    "comgen_per_pct_rec_tercil",
    "comgen_com_pct_rec_tercil"
)

# 4.2 Variables secundarias: se cruzan contra las recodificadas y el cluster ---
cfg$VARS_SEC <- c(
    "rph_sexo",
    "rph_nivel_rec",
    "rph_edad_rec",
    "rph_nse",
    "enc_region_rec",
    "vp_dc",
    "vp_dv",
    "desordenes_ind_rec",
    "incivilidades_ind_rec",
    "info_exp_personal",
    "info_otras_personas",
    "info_rrss",
    "info_prensa",
    "info_tv",
    "pergen_pais",
    "pergen_comuna",
    "pergen_barrio"
)

rm(ANIO_DEFECTO)
