#' Configuración del pipeline
#'
#' Reemplaza `config.R`. Sobreviven como parámetros los que no son rutas de
#' artefactos intermedios: esas las absorbe el almacén de `targets`.
#'
#' @return Una lista con los parámetros de la corrida.
construir_config <- function() {
    list(
        ANIO = 2025,
        CLUSTER_A_SACAR = "clusters_5",
        N_CLASES = 6:4,

        SVY_IDS = "conglomerado",
        # "var_strat", no "varstrat": clean_names() en seleccionar_variables()
        # convierte "VarStrat" a snake_case. El valor original nunca se había
        # ejercido porque el objeto de diseño muestral no existía en el DAG
        # hasta F5.3 (PLAN.md) — se corrige acá, al construirlo.
        SVY_STRATA = "var_strat",
        SVY_WEIGHTS = "fact_pers_reg",

        VARS_REC_TERCIL = c(
            "emper_ep_pct_rec_tercil",
            "emper_barrio_pct_rec_tercil",
            "emper_casa_pct_rec_tercil",
            "perper_delito",
            "comper_pct_rec_tercil",
            "comper_gasto",
            "comgen_per_pct_rec_tercil",
            "comgen_com_pct_rec_tercil"
        ),

        # PLAN.md F5.2, Q4: pergen_pais/comuna/barrio salieron de acá — la
        # dimensión "pergen" (ex P_AUMENTO) se descartó a propósito en
        # 1_select.R y esas tres columnas no existen en ningún punto del
        # pipeline. Bug heredado del config.R original; no cambiaba ningún
        # número porque reportar_composicion() ya las saltaba en silencio.
        VARS_SEC = c(
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
            "info_tv"
        )
    )
}

#' Verificar que las variables secundarias declaradas existan en los datos
#'
#' PLAN.md F5.2, Q4: cierra la clase de bug de `pergen_*` — aplica el patrón
#' declarado-vs-observado de §4.5 a `cfg` en vez de a una batería. Si algún
#' nombre de `VARS_SEC` deja de existir (o alguno nuevo debería agregarse y no
#' se hizo), falla nombrando la variable en vez de que `reportar_composicion()`
#' la salte en silencio.
#'
#' @param datos Datos finales (`datos_finales`).
#' @param vars_sec `cfg$VARS_SEC`.
#' @return `TRUE`, invisible, si todas las variables existen.
validar_vars_sec <- function(datos, vars_sec) {
    faltantes <- setdiff(vars_sec, names(datos))
    if (length(faltantes) > 0) {
        stop(
            "validar_vars_sec(): cfg$VARS_SEC declara columnas que no existen en datos_finales: ",
            paste(faltantes, collapse = ", ")
        )
    }
    invisible(TRUE)
}

#' Ruta del archivo original de la ola
#'
#' Separada de `construir_config()` para poder declararla con
#' `format = "file"` en el DAG sin invalidar el resto de `cfg` cuando cambia.
#'
#' @param anio Año de la ola.
#' @return La ruta al `.rds` original.
archivo_enusc_original <- function(anio) {
    file.path(
        "input/data/original",
        paste0("base-de-datos---enusc-", anio, ".RDS")
    )
}
