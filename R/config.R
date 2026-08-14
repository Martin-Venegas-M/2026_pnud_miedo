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
        SVY_STRATA = "var_strat",
        SVY_WEIGHTS = "fact_pers_reg",

        CORTES = list(
            # Dos ítems: el índice ya tiene tres valores, se usan como categorías.
            emper_barrio_pct = list(metodo = "valor", cortes = c(0, 50, 100)),
            emper_casa_pct = list(metodo = "valor", cortes = c(0, 50, 100)),
            # Sin código 85 en los ítems: el % equivale a un conteo de medidas.
            # Vivienda y barrio llevan cortes distintos a propósito: la medida
            # única del barrio es un grupo de WhatsApp en el 66% de los casos,
            # mientras que en la vivienda son rejas. El umbral que importa no es
            # el mismo.
            #* Estos dos se cuentan directo sobre la batería: no hay índice
            #* `_pct` intermedio. La clave nombra el grupo de ítems en
            #* `spec_indices`, no una columna de datos.
            comgen_per_pct = list(metodo = "conteo", cortes = c(0, 2)),
            comgen_com_pct = list(metodo = "conteo", cortes = c(0, 1)),
            # Todos los ítems admiten 85: el denominador varía por persona y un
            # conteo no sería comparable.
            emper_ep_pct = list(metodo = "porcentaje", cortes = c(0, 50)),
            comper_pct = list(metodo = "porcentaje", cortes = c(0, 50))
        ),

        VARS_MODELO = c(
            "emper_ep_pct_cat",
            "emper_barrio_pct_cat",
            "emper_casa_pct_cat",
            "perper_delito",
            "comper_pct_cat",
            "comper_gasto",
            "comgen_per_pct_cat",
            "comgen_com_pct_cat"
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
