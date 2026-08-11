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

# Pasar códigos de No aplica, No sabe y No responde a NA
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
sjmisc::frq(enusc_na$emper_ep_pct_rec_tercil) #* 85, 99 y 99 pasados a NA
sjmisc::frq(enusc_na$emper_barrio_pct_rec_tercil) #* 85, 99 y 99 pasados a NA
sjmisc::frq(enusc_na$emper_casa_pct_rec_tercil) #* 85, 99 y 99 pasados a NA
sjmisc::frq(enusc_na$perper_delito) #* Sigue igual
sjmisc::frq(enusc_na$comper_pct_rec_tercil) #* 85, 99 y 99 pasados a NA
sjmisc::frq(enusc_na$comper_gasto) #* 85, 99 y 99 pasados a NA
sjmisc::frq(enusc_na$comgen_per_pct_rec_tercil) #* 85, 99 y 99 pasados a NA
sjmisc::frq(enusc_na$comgen_com_pct_rec_tercil) #* 85, 99 y 99 pasados a NA

# Pasar categorías de perper_delito a NA
enusc_na <- enusc_na |>
    select(rph_id, all_of(rec_vars)) |>
    mutate(
        across(perper_delito, ~ replace(., which(. %in% c(4, 5)), NA)), # Pasar a NA categorías especificas de perper_delito
        across(all_of(rec_vars), ~ sjlabelled::to_label(.)) # Usar las categorías para los factores
    )

sjmisc::frq(enusc_na$perper_delito) #* Categorías pasadas a NA

#! IMPORTANTE: ELIMINAR NAS
df <- enusc_na |> drop_na()

# 3.2 Iterar soluciones -------------------------------------------------------
results_all <- map(
    cfg$N_CLASES,
    ~ mca_hcpc(df, n_class = .x)
) |>
    set_names(glue("class{cfg$N_CLASES}"))

# 3.3 Añadir variables de cluster ---------------------------------------------
add_clust <- function(data, nclust) {
    df_clust <- results_all[[glue("class{nclust}")]]$data |>
        select(all_of(c("rph_id", glue("clusters_{nclust}"))))

    data <- data |>
        left_join(df_clust) |>
        mutate(across(
            glue("clusters_{nclust}"),
            ~ factor(
                .,
                levels = c(1:nclust),
                labels = paste0("C", c(1:nclust))
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


# 4. Guardar -------------------------------------------------------------------

save(results_all, file = "output/models/mca_hcpc_456.RData")
saveRDS(enusc, file = cfg$FILE_ENUSC_ADDCLUST)
