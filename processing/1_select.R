#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Selección de las variables desde la bbdd original
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Este script contiene el código para un procesamiento
# inicial de los datos
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
        "janitor",
        "glue",
        "srvyr",
        "openxlsx",
        "scales"
    ),
    \(pkg) library(pkg, character.only = TRUE)
)

# 2. Cargar datos y funciones --------------------------------------------------

source("config.R", encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "functions.R"), encoding = "UTF-8")

enusc_original <- readRDS(cfg$FILE_ENUSC_ORIGINAL)

# 3. Ejecutar código -----------------------------------------------------------

# DIMENSIONES

# 1a. EMOCIONAL - PERSONAL (emper) = P_EXPOS_DELITO (P4), P_INSEG (P3)
# 1b EMOCIONAL- GENERAL (emgen) = No existe!

# 2a. PERCEPCTUAL- PERSONAL (perper) = P_EXPOS_DELITO (P7), P_DELITO_PRONOSTICO (P8)
#! 2b. PERCEPTUAL - GENERAL (pergen) = # Antes era P_AUMENTO (P1), pero la descartamos

# 3a. COMPORTAMIENTO - PERSONAL (comper) = P_MOD_ACTIVIDADES (P9), COSTOS_MEDIDAS (MDC6)
# 3b. COMPORTAMIENTO - GENERAL (comgen) = MEDIDAS (MDC2), VECINOS_MEDIDAS (MDC4),

# 3.1 Seleccionar variables ----------------------------------------------------
emper <- "P_INSEG"
perper <- "P_EXPOS_DELITO|P_DELITO_PRONOSTICO"
comper <- "P_MOD_ACTIVIDADES|COSTOS_MEDIDAS"
comgen <- "MEDIDAS|VECINOS"

enusc <- enusc_original |>
    filter(Kish == 1) |> # ! IMPORTANTE
    select(
        # Variables de muestra!
        rph_ID,
        idhogar,
        Conglomerado,
        VarStrat,
        Fact_Pers_Reg,
        Fact_Hog_Reg,
        # Variables fuente
        starts_with("P_INSEG"), # emper
        starts_with("P_EXPOS_DELITO"), # perper
        starts_with("P_DELITO_PRONOSTICO"), # perper
        starts_with("P_MOD_ACTIVIDADES"), # comper
        starts_with("COSTOS_MEDIDAS"), # comper
        starts_with("MEDIDAS"), # comgen
        starts_with("VECINOS_MEDIDAS"), # comgen
        # Variables secundarias
        starts_with("rph"),
        enc_region,
        VH_DC,
        VP_DC,
        VH_DV,
        VP_DV,
        starts_with("P_FUENTE_INFO_"),
        starts_with("P_DESORDENES_"),
        starts_with("P_INCIVILIDADES_")
    ) |>
    rename_with(~ glue("emper_{.x}"), matches(emper)) |>
    rename_with(~ glue("perper_{.x}"), matches(perper)) |>
    rename_with(~ glue("comper_{.x}"), matches(comper)) |>
    rename_with(~ glue("comgen_{.x}"), matches(comgen)) |>
    clean_names() |>
    rename(comper_costos_medidas = comgen_comper_costos_medidas) #! FIX MANUAL

rm(emper, perper, comper, comgen)

# 4. Guardar objetos -----------------------------------------------------------
saveRDS(enusc, cfg$FILE_ENUSC_SELECT)
