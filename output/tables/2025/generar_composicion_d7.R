#*******************************************************************************
# Composición de los 2.389 casos excluidos por D7 (Fase 3, PLAN.md)
# Institución: PNUD
# Resumen ejecutivo: reportar_composicion() sobre perper_delito == 4 (no
# sabe/no responde a la pregunta filtro "¿cree que será víctima de un
# delito?"), comparado contra el resto de la muestra. D7 resuelta con el
# usuario el 11 de agosto de 2026: se mantienen fuera del modelo (opción 1).
# Este reporte es el chequeo que motivó la decisión: verificar si esta
# pérdida, que nunca pasó por el criterio de §1, está sesgada.
#*******************************************************************************

library(targets)
library(dplyr)

tar_source("R")

cfg <- tar_read_raw("cfg")
final <- tar_read_raw("datos_finales")
delito <- tar_read_raw("datos_perper_delito")
cat4_ids <- delito$rph_id[delito$perper_delito == 4]

reporte <- reportar_composicion(
    datos = final,
    eliminados = final$rph_id %in% cat4_ids,
    vars_sec = cfg$VARS_SEC
)

readr::write_csv(
    reporte |>
        dplyr::mutate(grupo = dplyr::if_else(
            grupo == "eliminado",
            "categoria4_d7",
            "resto_muestra"
        )),
    "output/tables/2025/composicion_d7_categoria4.csv"
)

cat("N categoría 4 (D7):", length(cat4_ids), "\n")
cat("Filas escritas:", nrow(reporte), "\n")
