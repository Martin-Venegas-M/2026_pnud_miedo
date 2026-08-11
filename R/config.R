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
        SVY_STRATA = "varstrat",
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
            "info_tv",
            "pergen_pais",
            "pergen_comuna",
            "pergen_barrio"
        )
    )
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
