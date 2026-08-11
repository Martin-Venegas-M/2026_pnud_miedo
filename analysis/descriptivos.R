#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Descriptivos de variables recodificadas
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Este script contiene el código para la generación de
#                      descriptivos de las variables recodificadas, incluyendo
#                      los cruces por cluster en ambas direcciones de lectura.
# Fecha: 14 de septiembre de 2025
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
        "scales"
    ),
    \(pkg) library(pkg, character.only = TRUE)
)

# 2. Cargar datos y funciones --------------------------------------------------

source("tipologias/config.R", encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "functions.R"), encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS_AN, "functions.R"), encoding = "UTF-8")

enusc <- readRDS(cfg$FILE_ENUSC_ADDVARS)

enusc_svy <- enusc %>%
    as_survey_design(
        ids = !!sym(cfg$SVY_IDS),
        stata = !!sym(cfg$SVY_STRATA),
        weights = !!sym(cfg$SVY_WEIGHTS)
    )

# Cargar metadata
metadata_recode <- readxl::read_excel(cfg$FILE_METADATA)

# 3. Ejecutar código -----------------------------------------------------------

# 3.1 Variables recodificadas --------------------------------------------------

rec_vars <- map(
    cfg$VARS_REC,
    ~ tab_frq1(var = !!sym(.x), verbose = FALSE)
) %>%
    list_rbind() %>%
    pre_proc_excel(type = "tab_frq1")

# 3.2 Variables secundarias ----------------------------------------------------

sec_vars <- map(
    cfg$VARS_SEC,
    ~ tab_frq1(var = !!sym(.x), verbose = TRUE, sep_verbose = FALSE)
) %>%
    list_rbind() %>%
    pre_proc_excel()

# 3.3 Cruces variables recodificadas x variables secundarias -------------------

df <- expand_grid(
    rec_vars = cfg$VARS_REC,
    sec_vars = cfg$VARS_SEC
)

rec_sec_vars <- map2(
    df$rec_vars,
    df$sec_vars,
    ~ tab_frq2(
        var = !!sym(.x),
        grp = TRUE,
        grp_var = !!sym(.y),
        verbose = FALSE,
        vartype = NULL
    ),
    .progress = TRUE
) %>%
    set_names(str_trunc(
        glue(
            "{str_replace(df$rec_vars, '_pct_rec', '')}-{str_replace(df$sec_vars, 'rph_', '')}"
        ),
        30
    ))

# 3.4 Cruces variables x cluster -----------------------------------------------

#* Se generan las dos direcciones de lectura para cada conjunto de variables:
#*   invert = FALSE -> % de la variable dentro de cada cluster
#*   invert = TRUE  -> % de cada cluster dentro de cada categoría de la
#*                     variable (archivos "_inverted")
#*
#* Antes esto vivía en dos scripts casi idénticos (descriptivos.R y
#* descriptivos_inverted.R).
cruces_cluster <- expand_grid(
    conjunto = list(
        list(vars = cfg$VARS_REC, tipo = "rec"), # Recodificadas
        list(vars = cfg$VARS_SEC, tipo = "sec"), # Secundarias
        list(vars = cfg$VARS_REC2, tipo = "rec2") # Recodificadas dicotómicas + terciles
    ),
    invert = c(FALSE, TRUE)
)

clust_vars <- pmap(
    cruces_cluster,
    \(conjunto, invert) {
        tab_var_clust(
            svy = enusc_svy,
            clust_var = cfg$CLUSTER_A_SACAR,
            vector_vars = conjunto$vars,
            type_var_str = conjunto$tipo,
            invert = invert,
            save = TRUE
        )
    }
) %>%
    set_names(glue(
        "{map_chr(cruces_cluster$conjunto, 'tipo')}{if_else(cruces_cluster$invert, '_inv', '')}"
    ))

# 3.5 Univariados de recodificadas + terciles ----------------------------------

rec_vars2 <- map(
    cfg$VARS_REC2,
    ~ tab_frq1(var = !!sym(.x), verbose = FALSE)
) %>%
    list_rbind() %>%
    pre_proc_excel(type = "tab_frq1")

# 4. Guardar -------------------------------------------------------------------

# 4.1 Tablas ponderadas --------------------------------------------------------

# Univariados de recodificadas + secundarias (incluye metadata)
wb <- format_tab_excel(rec_vars, sheet = "Recodificadas ponderadas")
wb <- format_tab_excel(
    metadata_recode,
    wb = wb,
    sheet = "Metadata",
    var_col = "variable_recodificada",
    color_header = "#fcd5b4",
    sep_style = "dashed"
)
wb <- format_tab_excel(sec_vars, wb = wb, sheet = "Secundarias ponderadas")
saveWorkbook(
    wb,
    file.path(cfg$PATH_TABLES, "all_vars_tabs.xlsx"),
    overwrite = TRUE
)

# Bivariados recodificadas x secundarias
wb_tabs <- reduce(
    seq_along(rec_sec_vars),
    \(workbook, i) {
        format_tab_excel(
            pre_proc_excel(rec_sec_vars[[i]], type = "tab_frq2"),
            wb = workbook,
            sheet = names(rec_sec_vars)[[i]],
            var_col = names(rec_sec_vars[[i]][2]),
            sep_style = "dashed"
        )
    },
    .init = createWorkbook()
)
saveWorkbook(
    wb_tabs,
    file.path(cfg$PATH_TABLES, "rec_x_sec_vars_tabs.xlsx"),
    overwrite = TRUE
)

# 4.2 Tablas muestrales --------------------------------------------------------
# ! PENDIENTE
