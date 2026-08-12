library(targets)

tar_option_set(
    packages = c(
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
        "scales",
        "FactoMineR",
        "factoextra"
    ),
    memory = "transient",
    garbage_collection = TRUE
)

tar_source("R")

list(
    # -- Configuración -----------------------------------------------------
    tar_target(cfg, construir_config()),
    tar_target(
        archivo_original,
        archivo_enusc_original(cfg$ANIO),
        format = "file"
    ),

    # -- Selección (reemplaza 1_select.R) -----------------------------------
    tar_target(datos_original, leer_enusc(archivo_original)),
    tar_target(datos_muestra, filtrar_muestra(datos_original)),
    tar_target(
        log_muestra,
        reportar_transformacion(
            antes = datos_original,
            despues = datos_muestra,
            vars = character(0),
            etiqueta = "filtrar_muestra"
        )
    ),
    tar_target(datos_seleccionados, seleccionar_variables(datos_muestra, cfg)),
    tar_target(
        log_seleccionados,
        reportar_transformacion(
            antes = datos_muestra,
            despues = datos_seleccionados,
            vars = character(0),
            etiqueta = "seleccionar_variables"
        )
    ),

    # -- Recodificación (reemplaza 2_recode.R) ------------------------------
    tar_target(spec_indices, construir_spec_indices()),
    tar_target(spec_etiquetas_indices, construir_spec_etiquetas_indices()),

    tar_target(
        datos_indices_pct,
        construir_indices_pct(datos_seleccionados, spec_indices)
    ),
    tar_target(
        log_indices_pct,
        reportar_transformacion(
            antes = datos_seleccionados,
            despues = datos_indices_pct,
            vars = c(
                "emper_ep_pct",
                "emper_barrio_pct",
                "emper_casa_pct",
                "comper_pct",
                "comgen_per_pct",
                "comgen_com_pct"
            ),
            etiqueta = "indices_pct"
        )
    ),

    tar_target(
        datos_perper_delito,
        construir_perper_delito(datos_indices_pct)
    ),
    tar_target(
        log_perper_delito,
        reportar_transformacion(
            antes = datos_indices_pct,
            despues = datos_perper_delito,
            vars = "perper_delito",
            etiqueta = "perper_delito"
        )
    ),

    tar_target(
        datos_comper_gasto,
        construir_comper_gasto(datos_perper_delito)
    ),
    tar_target(
        log_comper_gasto,
        reportar_transformacion(
            antes = datos_perper_delito,
            despues = datos_comper_gasto,
            vars = "comper_gasto",
            etiqueta = "comper_gasto"
        )
    ),

    tar_target(
        datos_no_respuesta_comgen,
        marcar_no_respuesta_comgen(datos_comper_gasto)
    ),
    tar_target(
        log_no_respuesta_comgen,
        reportar_transformacion(
            antes = datos_comper_gasto,
            despues = datos_no_respuesta_comgen,
            vars = c("comgen_per_pct", "comgen_com_pct"),
            etiqueta = "no_respuesta_comgen"
        )
    ),

    tar_target(
        datos_categorizado,
        categorizar_indices(datos_no_respuesta_comgen)
    ),
    tar_target(
        log_categorizado,
        reportar_transformacion(
            antes = datos_no_respuesta_comgen,
            despues = datos_categorizado,
            vars = c(
                emper_ep_pct = "emper_ep_pct_rec_tercil",
                emper_barrio_pct = "emper_barrio_pct_rec_tercil",
                emper_casa_pct = "emper_casa_pct_rec_tercil",
                comper_pct = "comper_pct_rec_tercil",
                comgen_per_pct = "comgen_per_pct_rec_tercil",
                comgen_com_pct = "comgen_com_pct_rec_tercil"
            ),
            etiqueta = "categorizado"
        )
    ),

    tar_target(
        datos_codigos_recuperados,
        recuperar_codigos_especiales(datos_categorizado, spec_indices)
    ),
    tar_target(
        log_codigos_recuperados,
        reportar_transformacion(
            antes = datos_categorizado,
            despues = datos_codigos_recuperados,
            vars = c(
                "emper_ep_pct_rec_tercil",
                "emper_barrio_pct_rec_tercil",
                "emper_casa_pct_rec_tercil",
                "comper_pct_rec_tercil",
                "comgen_per_pct_rec_tercil",
                "comgen_com_pct_rec_tercil"
            ),
            etiqueta = "codigos_recuperados"
        )
    ),

    tar_target(
        datos_recodificados,
        etiquetar(datos_codigos_recuperados, spec_etiquetas_indices)
    ),
    tar_target(
        log_etiquetado,
        reportar_transformacion(
            antes = datos_codigos_recuperados,
            despues = datos_recodificados,
            vars = cfg$VARS_REC_TERCIL,
            etiqueta = "etiquetado_indices"
        )
    ),

    # -- MCA + HCPC (reemplaza 3_add_clust.R) -------------------------------
    tar_target(
        datos_prep_mca,
        preparar_datos_mca(datos_recodificados, cfg$VARS_REC_TERCIL)
    ),
    tar_target(
        datos_filtrados,
        filtrar_casos_completos(datos_prep_mca, cfg$VARS_REC_TERCIL)
    ),
    tar_target(
        log_perdida_mca,
        reportar_perdida(
            antes = datos_prep_mca,
            despues = datos_filtrados,
            vars = cfg$VARS_REC_TERCIL,
            etiqueta = "filtrar_casos_completos_mca",
            max_perdida = NULL
        )
    ),
    tar_target(
        log_composicion_mca,
        reportar_composicion(
            datos = datos_recodificados,
            eliminados = rowSums(is.na(datos_prep_mca[cfg$VARS_REC_TERCIL])) >
                0,
            vars_sec = cfg$VARS_SEC
        )
    ),

    tar_target(mca, ajustar_mca(datos_filtrados, id_col = "rph_id")),
    tar_target(hcpc, ajustar_hcpc_todos(mca, cfg$N_CLASES)),
    tar_target(soluciones, construir_soluciones(datos_filtrados, hcpc, cfg$N_CLASES)),

    tar_target(datos_clusters, pegar_clusters(datos_recodificados, soluciones)),
    tar_target(
        log_clusters,
        reportar_transformacion(
            antes = datos_recodificados,
            despues = datos_clusters,
            vars = paste0("clusters_", cfg$N_CLASES),
            etiqueta = "pegar_clusters"
        )
    ),

    # -- Variables secundarias (reemplaza 4_add_vars.R) ---------------------
    tar_target(spec_etiquetas_secundarias, construir_spec_etiquetas_secundarias()),

    tar_target(
        datos_indices_secundarios,
        construir_indices_secundarios(datos_clusters)
    ),
    tar_target(
        log_indices_secundarios,
        reportar_transformacion(
            antes = datos_clusters,
            despues = datos_indices_secundarios,
            vars = c(
                "desordenes_ind",
                "desordenes_ind_rec",
                "incivilidades_ind",
                "incivilidades_ind_rec"
            ),
            etiqueta = "indices_secundarios"
        )
    ),

    tar_target(
        datos_vars_info,
        construir_vars_info(datos_indices_secundarios)
    ),
    tar_target(
        log_vars_info,
        reportar_transformacion(
            antes = datos_indices_secundarios,
            despues = datos_vars_info,
            vars = c(
                "info_exp_personal",
                "info_otras_personas",
                "info_rrss",
                "info_prensa",
                "info_tv"
            ),
            etiqueta = "vars_info"
        )
    ),

    tar_target(
        datos_sociodemo,
        recodificar_sociodemograficas(datos_vars_info)
    ),
    tar_target(
        log_sociodemo,
        reportar_transformacion(
            antes = datos_vars_info,
            despues = datos_sociodemo,
            vars = c("rph_nivel_rec", "rph_edad_rec", "enc_region_rec"),
            etiqueta = "sociodemograficas"
        )
    ),

    tar_target(
        datos_finales,
        etiquetar(datos_sociodemo, spec_etiquetas_secundarias)
    ),
    tar_target(
        log_etiquetado_secundarias,
        reportar_transformacion(
            antes = datos_sociodemo,
            despues = datos_finales,
            vars = spec_etiquetas_secundarias$variables,
            etiqueta = "etiquetado_secundarias"
        )
    ),
    tar_target(
        validacion_vars_sec,
        validar_vars_sec(datos_finales, cfg$VARS_SEC)
    ),

    # -- Especificaciones para analysis/ (PLAN.md F5.2, Q3) ------------------
    tar_target(spec_patrones, construir_spec_patrones()),

    # -- Consolidación de logs -----------------------------------------------
    tar_target(
        logs_transformacion,
        list(
            muestra = log_muestra,
            seleccionados = log_seleccionados,
            indices_pct = log_indices_pct,
            perper_delito = log_perper_delito,
            comper_gasto = log_comper_gasto,
            no_respuesta_comgen = log_no_respuesta_comgen,
            categorizado = log_categorizado,
            codigos_recuperados = log_codigos_recuperados,
            etiquetado = log_etiquetado,
            clusters = log_clusters,
            indices_secundarios = log_indices_secundarios,
            vars_info = log_vars_info,
            sociodemo = log_sociodemo,
            etiquetado_secundarias = log_etiquetado_secundarias
        )
    ),
    tar_target(
        log_forma_csv,
        escribir_log_csv(
            logs_transformacion,
            "forma",
            "output/logs/forma.csv"
        ),
        format = "file"
    ),
    tar_target(
        log_marginales_csv,
        escribir_log_csv(
            logs_transformacion,
            "marginales",
            "output/logs/marginales.csv"
        ),
        format = "file"
    ),
    tar_target(
        log_transiciones_csv,
        escribir_log_csv(
            logs_transformacion,
            "transiciones",
            "output/logs/transiciones.csv"
        ),
        format = "file"
    ),
    tar_target(
        logs_perdida,
        list(mca = log_perdida_mca)
    ),
    tar_target(
        log_perdida_resumen_csv,
        escribir_log_csv(
            logs_perdida,
            "resumen",
            "output/logs/perdida_resumen.csv"
        ),
        format = "file"
    ),
    tar_target(
        log_perdida_detalle_csv,
        escribir_log_csv(
            logs_perdida,
            "detalle",
            "output/logs/perdida_detalle.csv"
        ),
        format = "file"
    ),
    tar_target(
        log_composicion_csv,
        {
            dir.create("output/logs", recursive = TRUE, showWarnings = FALSE)
            readr::write_csv(log_composicion_mca, "output/logs/composicion_mca.csv")
            "output/logs/composicion_mca.csv"
        },
        format = "file"
    ),

    # -- F5.3: tablas descriptivas --------------------------------------------
    tar_target(
        diseno_muestral,
        construir_diseno_muestral(
            datos_finales,
            cfg$SVY_IDS,
            cfg$SVY_STRATA,
            cfg$SVY_WEIGHTS
        )
    ),

    tar_target(
        mapeo_nombres,
        construir_mapeo_nombres(datos_muestra, datos_seleccionados)
    ),
    tar_target(
        mapeo_nombres_csv,
        {
            dir.create("output/tables/2025", recursive = TRUE, showWarnings = FALSE)
            readr::write_csv(mapeo_nombres, "output/tables/2025/mapeo_nombres.csv")
            "output/tables/2025/mapeo_nombres.csv"
        },
        format = "file"
    ),

    tar_target(
        vars_pct_continuas,
        c(
            "emper_ep_pct",
            "emper_barrio_pct",
            "emper_casa_pct",
            "comper_pct",
            "comgen_per_pct",
            "comgen_com_pct"
        )
    ),

    tar_target(
        tabla1_variables_originales,
        tabla_variables_originales(datos_seleccionados, spec_patrones)
    ),
    tar_target(
        tabla1_variables_originales_xlsx,
        escribir_tabla_descriptiva(
            tabla1_variables_originales,
            "output/tables/2025/tabla1_variables_originales",
            sheet = "variables_originales",
            motivo_provisional = NULL
        ),
        format = "file"
    ),

    tar_target(
        tabla2_variables_fuente,
        tabla_variables_fuente(
            datos_finales,
            vars_pct_continuas,
            cfg$VARS_REC_TERCIL
        )
    ),
    tar_target(
        tabla2_variables_fuente_xlsx,
        escribir_tabla_descriptiva(
            tabla2_variables_fuente,
            "output/tables/2025/tabla2_variables_fuente",
            sheet = "variables_fuente",
            motivo_provisional = "D2 abierta (PLAN.md): la categorización en terciles (ntile) de los índices _pct puede cambiar. Los índices _pct continuos no dependen de D2."
        ),
        format = "file"
    ),

    tar_target(
        tabla3_variables_secundarias,
        tabla_variables_secundarias(datos_finales, cfg$VARS_SEC)
    ),
    tar_target(
        tabla3_variables_secundarias_xlsx,
        escribir_tabla_descriptiva(
            tabla3_variables_secundarias,
            "output/tables/2025/tabla3_variables_secundarias",
            sheet = "variables_secundarias",
            motivo_provisional = "D5 abierta (PLAN.md): desordenes_ind_rec e incivilidades_ind_rec pueden cambiar de mecanismo/escala. El resto de VARS_SEC no depende de D5."
        ),
        format = "file"
    ),

    tar_target(
        tabla4_clusters,
        tabla_clusters(datos_finales, cfg$N_CLASES)
    ),
    tar_target(
        tabla4_clusters_xlsx,
        escribir_tabla_descriptiva(
            tabla4_clusters,
            "output/tables/2025/tabla4_clusters",
            sheet = "clusters",
            motivo_provisional = "D2 abierta (PLAN.md): la solución de cluster depende de la categorización que entra al MCA."
        ),
        format = "file"
    ),

    tar_target(
        tabla5_cruces_cluster,
        tabla_cruces_cluster(
            diseno_muestral,
            cfg$CLUSTER_A_SACAR,
            cfg$VARS_REC_TERCIL,
            cfg$VARS_SEC
        )
    ),
    tar_target(
        tabla5_cruces_cluster_xlsx,
        escribir_tabla_descriptiva(
            tabla5_cruces_cluster,
            "output/tables/2025/tabla5_cruces_cluster",
            sheet = "cruces_cluster",
            motivo_provisional = "D2 (categorización/clusters) y D5 (índices secundarios) abiertas (PLAN.md): el perfil de cada cluster puede cambiar en ambas partes."
        ),
        format = "file"
    ),

    tar_target(
        tabla6_v_test,
        tabla_v_test(hcpc, cfg$CLUSTER_A_SACAR)
    ),
    tar_target(
        tabla6_v_test_xlsx,
        escribir_tabla_descriptiva(
            tabla6_v_test,
            "output/tables/2025/tabla6_v_test",
            sheet = "v_test",
            motivo_provisional = "D2 abierta (PLAN.md): la solución de cluster completa (y por lo tanto qué variables la distinguen) puede cambiar."
        ),
        format = "file"
    )
)
