#*******************************************************************************
# 0. Identification ------------------------------------------------------------
# Título: Selección y descriptivos iniciales
# Institución: PNUD
# Responsable: Consultor técnico - MVM
# Resumen ejecutivo: Este script contiene el código para un procesamiento
# inicial de los datos y generación de descriptivos
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

source("tipologias/config.R", encoding = "UTF-8")
source(file.path(cfg$PATH_HELPERS, "functions.R"), encoding = "UTF-8")

enusc_original <- readRDS(cfg$FILE_ENUSC_SELECT)


# 3. Ejecutar código -----------------------------------------------------------

# 3.1. Descriptivos iniciales --------------------------------------------------

# Vectores de variables
dim_names <- c("emper", "perper", "pergen", "comper", "comgen")

emper_vars <- enusc %>%
    select(starts_with("emper")) %>%
    names()
perper_vars <- enusc %>%
    select(starts_with("perper")) %>%
    names()
pergen_vars <- enusc %>%
    select(starts_with("pergen")) %>%
    names()
comper_vars <- enusc %>%
    select(starts_with("comper")) %>%
    names()
#* tab_frq1() falla sobre una columna 100% NA, así que hay que excluirlas. Antes
#* iban nombradas a mano (comgen_adoptadas_na, comgen_vecinos_adoptadas_na), lo
#* que ata el código a una ola: en 2024 esas dos están vacías y en 2025 no, de
#* modo que la lista fija sirve para una ola y rompe la otra.
#* Detectarlas es equivalente en 2024 (excluye exactamente esas dos) y funciona
#* en cualquier ola sin editar nada. validar_seleccion() avisa igual si el
#* conjunto de columnas vacías cambia respecto de lo calibrado.
comgen_vars <- enusc %>%
    select(starts_with("comgen")) %>%
    select(where(\(x) !all(is.na(x)))) %>%
    names()

#* Cada batería separa su etiqueta de forma distinta, y eso cambia entre olas:
#* en 2025 comper reformuló la pregunta y el ítem quedó entre comillas dentro de
#* ella. Los patrones viven en ESPERADO, junto al resto de la calibración.
patrones <- esperado("patrones")

tabs_por_dim <- function(vars, patron) {
    map(
        vars,
        ~ tab_frq1(
            var = {{ .x }},
            pattern_verbose = patron$sep %||% "\\? ",
            extraer_verbose = patron$extraer
        )
    ) %>%
        set_names(vars)
}

# Iterar!
emper_tabs <- tabs_por_dim(emper_vars, patrones$emper)
perper_tabs <- tabs_por_dim(perper_vars, patrones$perper)
pergen_tabs <- tabs_por_dim(pergen_vars, patrones$pergen)
comper_tabs <- tabs_por_dim(comper_vars, patrones$comper)
comgen_tabs <- tabs_por_dim(comgen_vars, patrones$comgen)


# Guardar todas
all_tabs <- list(
    emper_tabs,
    perper_tabs,
    pergen_tabs,
    comper_tabs,
    comgen_tabs
) %>%
    set_names(dim_names)

# 4. Guardar objetos -----------------------------------------------------------

# Crear workbook vacio
wb_tabs <- createWorkbook()

# Iterar sobre el workbook para añadir las pestañas formateadas por dimensión
wb_tabs <- reduce2(
    seq_along(all_tabs),
    dim_names,
    \(workbook, data, sheetname) {
        format_tab_excel(
            df = all_tabs[[data]] %>% list_rbind() %>% pre_proc_excel(),
            wb = workbook,
            sheet = sheetname
        )
    },
    .init = wb_tabs
)

# Guardar el excel
saveWorkbook(
    wb_tabs,
    file.path(cfg$PATH_TABLES, "dim_vars_tabs.xlsx"),
    overwrite = TRUE
)

# Guardar lista con las tablas
save(all_tabs, file = file.path(cfg$PATH_TABLES, "all_tabs.RData"))
