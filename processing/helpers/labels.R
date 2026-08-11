# Crear etiquetas de variables
etiquetas_variables <- c(
    "Inseguridad en Espacio público" = "emper_ep_pct",
    "Inseguridad en Espacio público (tercile)" = "emper_ep_pct_rec_tercil",
    "Inseguridad en Barrio" = "emper_barrio_pct",
    "Inseguridad en Barrio (tercile)" = "emper_barrio_pct_rec_tercil",
    "Inseguridad en Casa" = "emper_casa_pct",
    "Inseguridad en Casa (tercile)" = "emper_casa_pct_rec_tercil",
    "Expectativa de ser victima delito" = "perper_delito",
    "Modifica comportamiento" = "comper_pct",
    "Modifica comportamiento (tercile)" = "comper_pct_rec_tercil",
    "Gasta en medidas de seguridad" = "comper_gasto",
    "Dispone de medidas de seguridad (personales)" = "comgen_per_pct",
    "Dispone de medidas de seguridad (personales) (tercile)" = "comgen_per_pct_rec_tercil",
    "Disponen de medidas de seguridad (comunitarias)" = "comgen_com_pct",
    "Disponen de medidas de seguridad (comunitarias) (tercile)" = "comgen_com_pct_rec_tercil"
)

etiquetas_valores <- list(
    "emper_ep_pct_rec_tercil" = c(
        "Alta inseguridad en espacio publico" = 3,
        "Media inseguridad en espacio publico" = 2,
        "Baja inseguridad en espacio publico" = 1,
        "No aplica" = 85,
        "No sabe" = 88,
        "No responde" = 99
    ),
    "emper_barrio_pct_rec_tercil" = c(
        "Alta inseguridad en el barrio" = 3,
        "Media inseguridad en el barrio" = 2,
        "Baja inseguridad en el barrio" = 1,
        "No aplica" = 85,
        "No sabe" = 88,
        "No responde" = 99
    ),
    "emper_casa_pct_rec_tercil" = c(
        "Alta inseguridad en la casa" = 3,
        "Media inseguridad en la casa" = 2,
        "Baja inseguridad en la casa" = 1,
        "No aplica" = 85,
        "No sabe" = 88,
        "No responde" = 99
    ),

    "perper_delito" = c(
        "No cree que será victima de delito" = 1,
        "Cree que será victima de delito no violento" = 2,
        "Cree que será victima de delito violento" = 3,
        "No sabe/No responde si cree que será victima de delito" = 4,
        "No sabe/No responde de qué delito será victima / Cree que será victima de otro tipo de delito" = 5
    ),
    "comper_pct_rec_tercil" = c(
        "Altas prácticas de evitación" = 3,
        "Medias prácticas de evitación" = 2,
        "Bajas prácticas de evitación" = 1,
        "No aplica" = 85,
        "No sabe" = 88,
        "No responde" = 99
    ),

    "comper_gasto" = c(
        "Gasta en medidas de seguridad" = 1,
        "No gasta en medidas de seguridad" = 0,
        "No sabe" = 88,
        "No responde" = 99
    ),

    "comgen_per_pct_rec_tercil" = c(
        "Alta disposición de medidas vivienda" = 3,
        "Media disposición de medidas vivienda" = 2,
        "Baja disposición de medidas vivienda" = 1,
        "No aplica" = 85,
        "No sabe" = 88,
        "No responde" = 99
    ),
    "comgen_com_pct_rec_tercil" = c(
        "Alta adopción de medidas comunitarias" = 3,
        "Media adopción de medidas comunitarias" = 2,
        "Baja adopción de medidas comunitarias" = 1,
        "No aplica" = 85,
        "No sabe" = 88,
        "No responde" = 99
    )
)
