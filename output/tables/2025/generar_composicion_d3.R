#*******************************************************************************
# Composición de los 78 casos rescatados por D3 (Fase 3, PLAN.md)
# Institución: PNUD
# Resumen ejecutivo: reportar_composicion() sobre el grupo perper_delito == 5
# ("otro tipo de delito", separado de no sabe/no responde por D3), comparado
# contra el resto de la muestra. Corrido específicamente para esta decisión,
# como pide el criterio de aceptación de Fase 3 ("una vez por cada decisión
# adoptada, no una sola vez al final").
#*******************************************************************************

library(targets)
library(dplyr)

tar_source("R")

cfg <- tar_read_raw("cfg")
final <- tar_read_raw("datos_finales")
otro <- tar_read_raw("datos_perper_delito")
rescatados_ids <- otro$rph_id[otro$perper_delito == 5]

reporte <- reportar_composicion(
    datos = final,
    eliminados = final$rph_id %in% rescatados_ids,
    vars_sec = cfg$VARS_SEC
)

readr::write_csv(
    reporte |> dplyr::rename(grupo = grupo) |>
        dplyr::mutate(grupo = dplyr::if_else(grupo == "eliminado", "otro_delito_d3", "resto_muestra")),
    "output/tables/2025/composicion_d3_otro_delito.csv"
)

cat("N grupo 'otro delito' (perper_delito==5):", length(rescatados_ids), "\n")
cat("Filas escritas:", nrow(reporte), "\n")
