#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: MCA de variables recodificadas
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Este script contiene el código para un análisis de
# correspondencias multiples
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
        "srvyr",
        "openxlsx",
        "scales",
        "FactoMineR",
        "factoextra"
    ),
    \(pkg) library(pkg, character.only = TRUE)
)

# 2. Cargar datos y funciones --------------------------------------------------

source("config.R", encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "functions.R"), encoding = "UTF-8")

enusc <- readRDS(cfg$FILE_ENUSC_RECODE)

# 3. Ejecutar código -----------------------------------------------------------

rec_vars <- cfg$VARS_REC_TERCIL

# 3.1 Preparar data ------------------------------------------------------------

enusc_na <- reduce(
    c(85, 88, 99), # Códigos a remover
    \(data, code) {
        print(glue("Removiendo el código {code} para las siguientes varables:"))
        data |>
            mutate(across(
                matches("emper|perper|pergen|comper|comgen"),
                ~ replace(., which(. %in% code), NA)
            ))
    },
    .init = enusc
)

# Ver!
sjmisc::frq(enusc_na$emper_ep_pct_rec_tercil)
sjmisc::frq(enusc_na$emper_barrio_pct_rec_tercil)
sjmisc::frq(enusc_na$emper_casa_pct_rec_tercil)
sjmisc::frq(enusc_na$perper_delito)
sjmisc::frq(enusc_na$comper_pct_rec_tercil)
sjmisc::frq(enusc_na$comper_gasto)
sjmisc::frq(enusc_na$comgen_per_pct_rec_tercil)
sjmisc::frq(enusc_na$comgen_com_pct_rec_tercil)

df_pre <- enusc_na %>%
    select(rph_id, all_of(rec_vars)) %>%
    mutate(
        across(everything(), ~ replace(., which(. == 85), NA)), # Pasar a NA los no aplica
        across(perper_delito, ~ replace(., which(. %in% c(4, 5)), NA)), # Pasar a NA categorías especificas de perper_delito
        across(all_of(rec_vars), ~ sjlabelled::to_label(.)) # Usar las categorías para los factores
    )

df <- df_pre %>% drop_na()

# 3.2 Iterar -------------------------------------------------------------------
results_all <- map(
    cfg$N_CLASES,
    ~ mca_hcpc(df, n_class = .x)
) %>%
    set_names(glue("class{cfg$N_CLASES}"))

# 4. Guardar -------------------------------------------------------------------

save(results_all, huella_input, file = cfg$FILE_MCA_HCPC)
