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
        "factoextra",
        "kableExtra"
    ),
    memory = "transient",
    garbage_collection = TRUE
)

tar_source("R")

list(
    # -- Configuración -----------------------------------------------------
    tar_target(cfg, construir_config()),

    #* Cortafuegos. `hcpc` y la preparación del modelo leen estos dos campos
    #* directo, y targets rastrea dependencias por target y no por campo: sin
    #* estos intermedios, cambiar cualquier cosa de `cfg` (el año, el diseño
    #* muestral, una etiqueta) invalida el HCPC aunque el modelo no lo mire.
    #* Con ellos, el cambio llega hasta acá, el valor sale igual y la cascada
    #* muere. Verificado en un proyecto targets aislado.
    tar_target(cfg_n_clases, cfg$N_CLASES),
    tar_target(cfg_vars_modelo, cfg$VARS_MODELO),

    #* No es un cortafuegos: nada caro lo lee. Existe como target para que la
    #* lista de columnas originales se derive de los diccionarios una sola vez
    #* y los tres targets que la usan lean el mismo vector.
    tar_target(
        cfg_vars_originales,
        vars_originales(cfg$INDICES, cfg$CODIGOS_COMGEN)
    ),
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

    tar_target(
        datos_indices_pct,
        construir_indices_pct(datos_seleccionados, cfg$INDICES)
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
                "comper_pct"
            ),
            etiqueta = "indices_pct"
        )
    ),

    # Las cuatro variables del modelo que no pasan por un índice: las dos que se
    # arman combinando respuestas del cuestionario y las dos de comgen, que se
    # cuentan sobre su batería. Un paso en vez de tres; la lógica de cada una
    # sigue en su propia función.
    tar_target(
        datos_sin_indice,
        construir_vars_sin_indice(
            datos_indices_pct,
            cfg$CORTES,
            cfg$INDICES,
            cfg$CODIGOS_COMGEN
        )
    ),
    tar_target(
        log_sin_indice,
        reportar_transformacion(
            antes = datos_indices_pct,
            despues = datos_sin_indice,
            vars = c(
                "perper_delito",
                "comper_gasto",
                "comgen_per_cat",
                "comgen_com_cat"
            ),
            etiqueta = "vars_sin_indice"
        )
    ),

    tar_target(
        datos_categorizado,
        categorizar_indices(datos_sin_indice, cfg$CORTES)
    ),
    tar_target(
        log_categorizado,
        reportar_transformacion(
            antes = datos_sin_indice,
            despues = datos_categorizado,
            #* Solo los cuatro índices: comgen se construye en el paso
            #* anterior y se registra en log_sin_indice.
            vars = c(
                emper_ep_pct = "emper_ep_pct_cat",
                emper_barrio_pct = "emper_barrio_pct_cat",
                emper_casa_pct = "emper_casa_pct_cat",
                comper_pct = "comper_pct_cat"
            ),
            etiqueta = "categorizado"
        )
    ),

    tar_target(
        datos_no_respuesta_rescatada,
        rescatar_no_respuesta(datos_categorizado, cfg$INDICES, cfg$CORTES)
    ),
    tar_target(
        log_rescate_no_respuesta,
        reportar_transformacion(
            antes = datos_categorizado,
            despues = datos_no_respuesta_rescatada,
            #* Solo las cuatro de índice: las de comgen ya traen sus códigos
            #* desde categorizar_comgen() y se registran en log_sin_indice.
            vars = c(
                "emper_ep_pct_cat",
                "emper_barrio_pct_cat",
                "emper_casa_pct_cat",
                "comper_pct_cat"
            ),
            etiqueta = "rescate_no_respuesta"
        )
    ),

    tar_target(
        datos_recodificados,
        etiquetar(datos_no_respuesta_rescatada, cfg$ETIQUETAS)
    ),
    tar_target(
        log_etiquetado,
        reportar_transformacion(
            antes = datos_no_respuesta_rescatada,
            despues = datos_recodificados,
            vars = cfg_vars_modelo,
            etiqueta = "etiquetado_indices"
        )
    ),

    # Diagnóstico del método "valor": a cuánta gente le aplica un solo momento
    # del día. La página lo cita; ver el docstring para qué supuesto mide.
    tar_target(
        diagnostico_aplicabilidad,
        medir_aplicabilidad(
            datos_seleccionados,
            datos_recodificados,
            cfg$INDICES,
            cfg$CORTES
        )
    ),

    # -- MCA + HCPC (reemplaza 3_add_clust.R) -------------------------------
    tar_target(
        datos_prep_mca,
        preparar_datos_mca(datos_recodificados, cfg_vars_modelo)
    ),
    tar_target(
        datos_filtrados,
        filtrar_casos_completos(datos_prep_mca, cfg_vars_modelo)
    ),
    tar_target(
        log_perdida_mca,
        reportar_perdida(
            antes = datos_prep_mca,
            despues = datos_filtrados,
            vars = cfg_vars_modelo,
            etiqueta = "filtrar_casos_completos_mca",
            max_perdida = NULL
        )
    ),
    tar_target(
        log_composicion_mca,
        reportar_composicion(
            datos = datos_recodificados,
            eliminados = rowSums(is.na(datos_prep_mca[cfg_vars_modelo])) >
                0,
            vars_sec = cfg$VARS_SEC
        )
    ),

    tar_target(mca, ajustar_mca(datos_filtrados, id_col = "rph_id")),
    tar_target(hcpc, ajustar_hcpc_todos(mca, cfg_n_clases)),
    tar_target(soluciones, construir_soluciones(datos_filtrados, hcpc, cfg_n_clases)),

    tar_target(datos_clusters, pegar_clusters(datos_recodificados, soluciones)),
    tar_target(
        log_clusters,
        reportar_transformacion(
            antes = datos_recodificados,
            despues = datos_clusters,
            vars = paste0("clusters_", cfg_n_clases),
            etiqueta = "pegar_clusters"
        )
    ),

    # -- Variables secundarias (reemplaza 4_add_vars.R) ---------------------

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
        etiquetar(datos_sociodemo, cfg$ETIQUETAS_SEC)
    ),
    tar_target(
        log_etiquetado_secundarias,
        reportar_transformacion(
            antes = datos_sociodemo,
            despues = datos_finales,
            vars = cfg$ETIQUETAS_SEC$variables,
            etiqueta = "etiquetado_secundarias"
        )
    ),
    tar_target(
        validacion_vars_sec,
        validar_vars_sec(datos_finales, cfg$VARS_SEC)
    ),

    # -- Especificaciones para analysis/ (PLAN.md F5.2, Q3) ------------------

    # -- Consolidación de logs -----------------------------------------------
    tar_target(
        logs_transformacion,
        list(
            muestra = log_muestra,
            seleccionados = log_seleccionados,
            indices_pct = log_indices_pct,
            vars_sin_indice = log_sin_indice,
            categorizado = log_categorizado,
            rescate_no_respuesta = log_rescate_no_respuesta,
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
        tabla1_variables_originales,
        tabla_variables_originales(datos_seleccionados, cfg$PATRONES)
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
            cfg$VARS_PCT,
            cfg_vars_modelo
        )
    ),
    tar_target(
        tabla2_variables_fuente_xlsx,
        escribir_tabla_descriptiva(
            tabla2_variables_fuente,
            "output/tables/2025/tabla2_variables_fuente",
            sheet = "variables_fuente"
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
            sheet = "variables_secundarias"
        ),
        format = "file"
    ),

    tar_target(
        tabla4_clusters,
        tabla_clusters(datos_finales, cfg_n_clases)
    ),
    tar_target(
        tabla4_clusters_xlsx,
        escribir_tabla_descriptiva(
            tabla4_clusters,
            "output/tables/2025/tabla4_clusters",
            sheet = "clusters"
        ),
        format = "file"
    ),

    tar_target(
        tabla5_cruces_cluster,
        tabla_cruces_cluster(
            diseno_muestral,
            cfg$CLUSTER_A_SACAR,
            cfg_vars_modelo,
            cfg$VARS_SEC
        )
    ),
    tar_target(
        tabla5_cruces_cluster_xlsx,
        escribir_tabla_descriptiva(
            tabla5_cruces_cluster,
            "output/tables/2025/tabla5_cruces_cluster",
            sheet = "cruces_cluster"
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
            sheet = "v_test"
        ),
        format = "file"
    ),

    # -----------------------------------------------------------------------
    # Insumos de la página (PLAN.md F5.4)
    #
    # El .qmd no calcula: todo número que aparezca en la página nace acá.
    # -----------------------------------------------------------------------

    tar_target(tabla_ajuste, tabla_ajuste_global(mca)),
    tar_target(
        tabla_ajuste_xlsx,
        escribir_tabla_descriptiva(
            tabla_ajuste,
            "output/tables/2025/tabla_ajuste_global",
            sheet = "ajuste_global",
            var_col = "dimension"
        ),
        format = "file"
    ),

    tar_target(
        tabla_cruces_ancho_clusters,
        tabla_cruces_ancho(tabla5_cruces_cluster, cfg$CLUSTER_A_SACAR)
    ),

    # Las tres soluciones (4, 5 y 6 grupos) para las subpestañas de la página.
    tar_target(
        cruces_ancho_todas,
        tabla_cruces_ancho_todas(
            diseno_muestral,
            cfg_n_clases,
            cfg_vars_modelo,
            cfg$VARS_SEC
        )
    ),
    tar_target(v_test_todas, tabla_v_test_todas(hcpc, cfg_n_clases)),

    # La misma diferencia en puntos porcentuales que v_test_todas, pero estimada
    # con el diseño muestral en vez de salir de catdes(). El universo se fija con
    # una sola solución porque los casos que entran al modelo (49.503) son los
    # mismos en las tres.
    tar_target(
        marginales_modelo,
        marginales_ponderadas(
            diseno_muestral,
            paste0("clusters_", cfg_n_clases[1]),
            c(cfg_vars_modelo, cfg$VARS_SEC)
        )
    ),
    tar_target(
        lift_ponderado,
        tabla_lift_ponderado(cruces_ancho_todas, marginales_modelo)
    ),

    # Lo mismo para las columnas originales que construyen las ocho variables
    # del modelo, que la página muestra como su propia tabla de perfil. Es el
    # paso más caro de esta zona: 67 columnas por tres soluciones, ~9 minutos.
    tar_target(
        etiquetas_orig,
        etiquetas_originales(datos_finales, cfg_vars_originales, cfg$BATERIAS)
    ),
    tar_target(
        orden_categorias_orig,
        orden_categorias_originales(datos_finales, cfg_vars_originales)
    ),
    tar_target(
        cruces_originales_todas,
        tabla_cruces_originales_todas(
            diseno_muestral,
            cfg_n_clases,
            cfg_vars_originales
        )
    ),
    tar_target(
        marginales_originales,
        marginales_ponderadas(
            diseno_muestral,
            paste0("clusters_", cfg_n_clases[1]),
            cfg_vars_originales
        )
    ),
    tar_target(
        lift_ponderado_originales,
        tabla_lift_ponderado(cruces_originales_todas, marginales_originales)
    ),

    # Las tres soluciones son el mismo árbol cortado a tres alturas. Este target
    # identifica los bloques terminales y verifica que el anidamiento sea exacto.
    tar_target(bloques, bloques_soluciones(datos_finales, cfg_n_clases)),

    tar_target(no_respuesta_indices, medir_no_respuesta_indices(datos_finales)),
    tar_target(
        metadata_variables,
        construir_metadata(
            datos_seleccionados,
            datos_finales,
            mapeo_nombres,
            cfg$INDICES,
            cfg_vars_modelo,
            cfg$VARS_SEC,
            cfg_n_clases,
            cfg$CODIGOS_COMGEN,
            cfg$SECUNDARIAS
        )
    ),
    tar_target(
        metadata_xlsx,
        escribir_tabla_descriptiva(
            metadata_variables,
            "output/tables/2025/metadata_variables",
            sheet = "diccionario",
            var_col = "familia"
        ),
        format = "file"
    ),
    tar_target(datos_biplot_mca, datos_biplot(mca)),
    tar_target(mapa_clusters, datos_mapa_clusters(mca, hcpc, cfg_n_clases)),
    tar_target(
        matriz_perfil,
        datos_matriz_perfil(v_test_todas, lift_ponderado, datos_biplot_mca)
    ),
    tar_target(
        tabla_cruces_ancho_xlsx,
        escribir_tabla_descriptiva(
            tabla_cruces_ancho_clusters,
            "output/tables/2025/tabla_cruces_ancho",
            sheet = "cruces_ancho"
        ),
        format = "file"
    )
)
