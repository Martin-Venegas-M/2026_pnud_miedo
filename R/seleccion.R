#' Leer la base ENUSC original
#'
#' @param archivo Ruta al `.rds` original.
#' @return El data frame leído, sin modificar.
leer_enusc <- function(archivo) {
    readRDS(archivo)
}

#' Filtrar el informante Kish del hogar
#'
#' @param datos Base original.
#' @return `datos` con solo los casos `Kish == 1`.
filtrar_muestra <- function(datos) {
    datos |> dplyr::filter(Kish == 1)
}

#' Seleccionar y renombrar las variables que entran al análisis
#'
#' Selecciona las variables de muestra, las fuente de cada dimensión y las
#' secundarias, y prefija las de dimensión (`emper_`, `perper_`, `comper_`,
#' `comgen_`) según el patrón de su nombre original.
#'
#' @param datos Base filtrada por Kish.
#' @param cfg Configuración de la corrida (no se usa hoy en la selección;
#'   se recibe por consistencia con la firma declarada en el plan).
#' @return La base con las columnas seleccionadas y renombradas.
#'
#' @details
#' Los cuatro `rename_with()` se aplican en secuencia sobre TODAS las columnas
#' presentes en ese momento, no solo sobre las originales: el regex de
#' `comgen` (`"MEDIDAS|VECINOS"`) coincide también con `comper_COSTOS_MEDIDAS`,
#' ya renombrada por el paso anterior, y la vuelve a prefijar como
#' `comgen_comper_costos_medidas`. El `rename()` final corrige ese
#' solapamiento.
seleccionar_variables <- function(datos, cfg) {
    emper <- "P_INSEG"
    perper <- "P_EXPOS_DELITO|P_DELITO_PRONOSTICO"
    comper <- "P_MOD_ACTIVIDADES|COSTOS_MEDIDAS"
    comgen <- "MEDIDAS|VECINOS"

    datos <- datos |>
        dplyr::select(
            # Variables de muestra
            rph_ID,
            idhogar,
            Conglomerado,
            VarStrat,
            Fact_Pers_Reg,
            Fact_Hog_Reg,
            # Variables fuente
            dplyr::starts_with("P_INSEG"), # emper
            dplyr::starts_with("P_EXPOS_DELITO"), # perper
            dplyr::starts_with("P_DELITO_PRONOSTICO"), # perper
            dplyr::starts_with("P_MOD_ACTIVIDADES"), # comper
            dplyr::starts_with("COSTOS_MEDIDAS"), # comper
            dplyr::starts_with("MEDIDAS"), # comgen
            dplyr::starts_with("VECINOS_MEDIDAS"), # comgen
            # Variables secundarias
            dplyr::starts_with("rph"),
            enc_region,
            VH_DC,
            VP_DC,
            VH_DV,
            VP_DV,
            dplyr::starts_with("P_FUENTE_INFO_"),
            dplyr::starts_with("P_DESORDENES_"),
            dplyr::starts_with("P_INCIVILIDADES_"),
            dplyr::starts_with("P_AUMENTO_")
        ) |>
        dplyr::rename_with(~ glue::glue("emper_{.x}"), dplyr::matches(emper)) |>
        dplyr::rename_with(
            ~ glue::glue("perper_{.x}"),
            dplyr::matches(perper)
        ) |>
        dplyr::rename_with(
            ~ glue::glue("comper_{.x}"),
            dplyr::matches(comper)
        ) |>
        dplyr::rename_with(
            ~ glue::glue("comgen_{.x}"),
            dplyr::matches(comgen)
        ) |>
        janitor::clean_names() |>
        dplyr::rename(comper_costos_medidas = comgen_comper_costos_medidas) # ! FIX MANUAL, ver detalles arriba

    # Regla #6: verificar el supuesto antes de construir sobre él. El
    # solapamiento entre regex de dimensión es conocido y se corrige arriba;
    # esta aserción falla si aparece uno nuevo en vez de dejar pasar un
    # nombre raro en silencio.
    if (!"comper_costos_medidas" %in% names(datos)) {
        rlang::abort("Falta `comper_costos_medidas` tras el renombrado.")
    }
    if (any(grepl("^comgen_comper_|^comper_comgen_", names(datos)))) {
        rlang::abort(c(
            "Quedó un prefijo de dimensión duplicado tras el renombrado.",
            i = "Apareció un solapamiento nuevo entre los regex de dimensión."
        ))
    }

    datos
}
