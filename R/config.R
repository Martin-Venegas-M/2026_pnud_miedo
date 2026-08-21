#' Configuración del pipeline
#'
#' Los parámetros de la corrida y todos los diccionarios del análisis en un solo
#' objeto: los cortes, los vectores de variables, los ítems de cada batería y las
#' etiquetas.
#'
#' @details
#' `targets` rastrea dependencias por target y no por campo, así que cualquier
#' cambio acá invalida todo lo que lea `cfg`. Los dos campos que la parte cara
#' del pipeline necesita, `N_CLASES` y `VARS_MODELO`, se exponen como targets
#' aparte para que editar un corte o una etiqueta no obligue a recalcular el
#' modelo.
#'
#' @return Una lista con los parámetros de la corrida.
construir_config <- function() {
    #* Se declara aparte para poder derivar de él la lista de índices que sí
    #* existen como columna `_pct`, en vez de escribirla a mano en _targets.R.
    cortes <- list(

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
        #* `cfg$INDICES`, no una columna de datos.
        comgen_per = list(metodo = "conteo", cortes = c(0, 2)),
        comgen_com = list(metodo = "conteo", cortes = c(0, 1)),
        # Todos los ítems admiten 85: el denominador varía por persona y un
        # conteo no sería comparable.
        emper_ep_pct = list(metodo = "porcentaje", cortes = c(0, 50)),
        comper_pct = list(metodo = "porcentaje", cortes = c(0, 50))
    )

    list(
        ANIO = 2025,
        CLUSTER_A_SACAR = "clusters_5",
        N_CLASES = 6:4,

        SVY_IDS = "conglomerado",
        SVY_STRATA = "var_strat",
        SVY_WEIGHTS = "fact_pers_reg",

        CORTES = cortes,

        VARS_MODELO = c(
            "emper_ep_pct_cat",
            "emper_barrio_pct_cat",
            "emper_casa_pct_cat",
            "perper_delito",
            "comper_pct_cat",
            "comper_gasto",
            "comgen_per_cat",
            "comgen_com_cat"
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
            #* Las tres de percepción de aumento del delito. Entran como
            #* secundarias, sin recodificar: describen a los grupos y no los
            #* construyen. La dimensión perceptual general sigue fuera del
            #* modelo, que es una decisión distinta de esta.
            "p_aumento_pais",
            "p_aumento_com",
            "p_aumento_barrio",
            "info_exp_personal",
            "info_otras_personas",
            "info_rrss",
            "info_prensa",
            "info_tv"
        ),

        #* Los índices que dejan una columna `_pct`: todos menos los de método
        #* "conteo", que se categorizan contando la batería.
        VARS_PCT = names(cortes)[
            purrr::map_lgl(cortes, \(s) s$metodo != "conteo")
        ],

        #* Diccionarios. Las funciones viven junto a sus consumidores; acá se
        #* consolidan en `cfg` para que el DAG no lleve un target por cada
        #* declaración. Ver los cortafuegos `cfg_n_clases` y `cfg_vars_modelo`
        #* en _targets.R: son los que evitan que tocar un diccionario recorra
        #* el HCPC.
        INDICES = spec_indices(),
        BATERIAS = spec_baterias_originales(),
        ETIQUETAS = spec_etiquetas_indices(),
        ETIQUETAS_SEC = spec_etiquetas_secundarias(),
        PATRONES = spec_patrones(),
        CODIGOS_COMGEN = spec_codigos_comgen(),
        SECUNDARIAS = spec_secundarias()
    )
}

#' Verificar que las variables secundarias declaradas existan en los datos
#'
#' Si algún nombre de `VARS_SEC` deja de existir en los datos, falla nombrando la
#' variable. Sin esta comprobación, las funciones que recorren esa lista se
#' saltan la columna faltante sin avisar, y una tabla aparece incompleta sin que
#' nada indique por qué.
#'
#' @param datos Datos finales (`datos_finales`).
#' @param vars_sec `cfg$VARS_SEC`.
#' @return `TRUE`, invisible, si todas las variables existen.
validar_vars_sec <- function(datos, vars_sec) {
    faltantes <- setdiff(vars_sec, names(datos))
    if (length(faltantes) > 0) {
        rlang::abort(c(
            "cfg$VARS_SEC declara columnas que no existen en los datos.",
            x = paste("Faltan:", paste(faltantes, collapse = ", "))
        ))
    }
    invisible(TRUE)
}

#' Especificación de los ítems fuente de cada índice
#'
#' Qué columnas originales componen cada batería. Va dentro de `cfg$INDICES` y
#' es el insumo de la construcción de índices, de la categorización por conteo y
#' del diccionario de variables.
#'
#' @details
#' **Las columnas `_na` de `comgen` quedan fuera a propósito.** Registran
#' "ninguna medida de seguridad", que es una respuesta y no una medida más. Si
#' se incluyen en la batería, quien responde "ninguna" obtiene un ítem en 1 y
#' nunca llega a 0% de adopción. Dejándolas fuera, esa persona tiene todos los
#' ítems en 0 y el cero sale del cálculo mismo, sin ningún caso especial.
#'
#' **Qué situaciones entran en el índice de espacio público también es una
#' decisión.** La batería de lugares tiene más ítems de los que el índice usa:
#' quedan fuera los referidos al propio barrio, que es una dimensión aparte, y
#' los espacios de uso propio o de acceso restringido.
#'
#' @return Una lista nombrada, un elemento por índice. `perper_delito` es una
#'   lista anidada, documentación de las seis ramas de su `case_when` (ver
#'   `construir_perper_delito()`) — no la usa `construir_perper_delito()`
#'   directamente (esa hardcodea sus propios grupos), es solo para que quede
#'   trazado en el mismo lugar que el resto de las especificaciones.
spec_indices <- function() {
    list(
        emper_ep_pct = paste0("emper_p_inseg_lugares_", 1:11),
        emper_barrio_pct = c("emper_p_inseg_oscuro_1", "emper_p_inseg_dia_1"),
        emper_casa_pct = c("emper_p_inseg_oscuro_2", "emper_p_inseg_dia_2"),
        perper_delito = list(
            "perper_p_expos_delito",
            paste0("perper_p_delito_pronostico_", c(1:4, 6, 9:11)),
            paste0("perper_p_delito_pronostico_", c(5, 7:8)),
            "perper_p_expos_delito",
            paste0("perper_p_delito_pronostico_", 77),
            paste0("perper_p_delito_pronostico_", c(88, 99))
        ),
        comper_pct = paste0("comper_p_mod_actividades_", 1:13),
        comper_gasto = c("comper_costos_medidas"),
        comgen_per = c(
            "comgen_medidas_perro",
            "comgen_medidas_alarma_privada",
            "comgen_medidas_camaras_vigilancia",
            "comgen_medidas_rejas",
            "comgen_medidas_cerco",
            "comgen_medidas_proteccion",
            "comgen_medidas_seguro",
            "comgen_medidas_foco",
            "comgen_medidas_otro"
        ),
        comgen_com = c(
            "comgen_vecinos_medidas_whatsapp",
            "comgen_vecinos_medidas_vigilancia",
            "comgen_vecinos_medidas_al_comunit",
            "comgen_vecinos_medidas_coord_pol",
            "comgen_vecinos_medidas_coord_mun",
            "comgen_vecinos_medidas_televig",
            "comgen_vecinos_medidas_privad",
            "comgen_vecinos_medidas_otro"
        )
    )
}

#' Baterías de las variables originales, para rotularlas
#'
#' Las columnas originales llegan con la etiqueta completa de la ENUSC, que
#' repite la pregunta entera en cada ítem: los once lugares del índice de
#' espacio público empiezan los once con "Durante los últimos doce meses, según
#' su experiencia, ¿qué tan seguro/a se siente...?". Para mostrarlas en una
#' tabla hay que quedarse con el ítem, y para eso hace falta saber qué columnas
#' comparten pregunta.
#'
#' @section Por qué se declara por patrón de nombre y no por lista de columnas:
#' La pertenencia a batería ya está implícita en `cfg$INDICES`, pero no calza:
#' `perper_delito` mezcla en un mismo elemento la pregunta filtro
#' (`perper_p_expos_delito`) con los catorce ítems del pronóstico, que son otra
#' pregunta; y las columnas de código especial de `comgen` no viven ahí sino en
#' `cfg$CODIGOS_COMGEN`. Un patrón sobre el nombre de la columna agrupa las ocho
#' baterías reales sin duplicar los vectores de variables.
#'
#' @section Alternativa descartada:
#' Agrupar por los primeros caracteres de la etiqueta funciona sobre estos datos
#' (da las mismas ocho baterías, verificado), pero depende de que dos preguntas
#' distintas nunca empiecen igual, que es una propiedad del texto del
#' cuestionario y no algo que el análisis controle. El patrón sobre el nombre de
#' la columna sí lo controla el pipeline.
#'
#' @section Las dos baterías de un solo ítem:
#' `perper_p_expos_delito` y `comper_costos_medidas` son preguntas sueltas, no
#' baterías. No tienen ítem que separar, así que se rotulan con el nombre de la
#' batería a secas. Están declaradas igual para que toda columna original
#' pertenezca a exactamente una batería y la aserción pueda ser total.
#'
#' @return Un vector nombrado: nombre legible de la batería = patrón que matchea
#'   sus columnas.
spec_baterias_originales <- function() {
    c(
        "Inseguridad en lugares" = "^emper_p_inseg_lugares_",
        "Inseguridad en el barrio y la casa" = "^emper_p_inseg_(oscuro|dia)_",
        "Expectativa de victimización" = "^perper_p_expos_delito$",
        "Delito que espera" = "^perper_p_delito_pronostico_",
        "Prácticas que dejó de hacer" = "^comper_p_mod_actividades_",
        "Gasto en medidas de seguridad" = "^comper_costos_medidas$",
        "Medidas de la vivienda" = "^comgen_medidas_",
        "Medidas del barrio" = "^comgen_vecinos_medidas_"
    )
}

#' Las columnas originales que construyen las variables del modelo
#'
#' Se deriva de los dos diccionarios que ya declaran esa lineage en vez de
#' escribirse a mano, para que agregar un ítem a una batería lo traiga a las
#' tablas sin tocar dos lugares.
#'
#' @section Qué queda fuera:
#' Los cinco ítems de la batería de lugares que el índice de espacio público no
#' usa. La batería tiene dieciséis y el índice once: quedan fuera los referidos
#' al propio barrio, que es otra dimensión, y los espacios de uso propio o de
#' acceso restringido. Como no participan de ninguna variable del modelo,
#' tampoco participan de su descripción.
#'
#' @section Por qué entran las columnas de código especial de `comgen`:
#' Las seis columnas `_ns`, `_nr` y `_na` de las dos baterías de opción múltiple
#' son estructuralmente idénticas a las de las medidas: una columna dummy por
#' alternativa. Dos de ellas se leen (estampan "no sabe" y "no responde" sobre
#' la variable categorizada) y la tercera registra "ninguna medida de
#' seguridad", que es una respuesta sustantiva. Dejarlas fuera de la
#' descripción escondería justamente la alternativa cuyo tratamiento decide el
#' análisis.
#'
#' @param indices `cfg$INDICES`.
#' @param codigos_comgen `cfg$CODIGOS_COMGEN`.
#' @return Un vector de nombres de columna, sin repetidos, en el orden en que
#'   los declaran los diccionarios. `perper_p_expos_delito` aparece dos veces en
#'   `cfg$INDICES`, una por cada rama del `case_when` que la usa.
vars_originales <- function(indices, codigos_comgen) {
    unique(c(
        unlist(indices, use.names = FALSE),
        unname(unlist(codigos_comgen))
    ))
}

#' Especificación de etiquetas de los índices recodificados
#'
#' Va dentro de `cfg$ETIQUETAS`, y se aplica al final de la recodificación.
#'
#' @return Una lista con `variables` (vector nombrado etiqueta = variable) y
#'   `valores` (lista nombrada variable = vector nombrado etiqueta = código).
spec_etiquetas_indices <- function() {
    list(
        variables = c(
            "Inseguridad en Espacio público" = "emper_ep_pct",
            "Inseguridad en espacio público (categorizada)" = "emper_ep_pct_cat",
            "Inseguridad en Barrio" = "emper_barrio_pct",
            "Inseguridad en el barrio (categorizada)" = "emper_barrio_pct_cat",
            "Inseguridad en Casa" = "emper_casa_pct",
            "Inseguridad en la casa (categorizada)" = "emper_casa_pct_cat",
            "Expectativa de ser victima delito" = "perper_delito",
            "Modifica comportamiento" = "comper_pct",
            "Modificación de prácticas (categorizada)" = "comper_pct_cat",
            "Gasta en medidas de seguridad" = "comper_gasto",
            #* Los dos `comgen_*_pct` salieron del pipeline: se categorizan
            #* directo desde la batería y no hay índice que etiquetar.
            "Medidas de seguridad de la vivienda (categorizada)" = "comgen_per_cat",
            "Medidas de seguridad del barrio (categorizada)" = "comgen_com_cat"
        ),
        valores = list(
            "emper_ep_pct_cat" = c(
                "Sin inseguridad en espacio público" = 1,
                "Inseguridad en hasta la mitad de los lugares" = 2,
                "Inseguridad en más de la mitad de los lugares" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "emper_barrio_pct_cat" = c(
                "Sin inseguridad en el barrio" = 1,
                "Inseguridad en el barrio, de día o de noche" = 2,
                "Inseguridad en el barrio, de día y de noche" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "emper_casa_pct_cat" = c(
                "Sin inseguridad en la casa" = 1,
                "Inseguridad en la casa, de día o de noche" = 2,
                "Inseguridad en la casa, de día y de noche" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "perper_delito" = c(
                "No cree que será victima de delito" = 1,
                "Cree que será victima de delito no violento" = 2,
                "Cree que será victima de delito violento" = 3,
                "No sabe/No responde si cree que será victima de delito" = 4,
                "Cree que será victima de otro tipo de delito" = 5,
                "No sabe/No responde de qué delito será victima" = 6
            ),
            "comper_pct_cat" = c(
                "No modificó prácticas" = 1,
                "Modificó hasta la mitad de las prácticas" = 2,
                "Modificó más de la mitad de las prácticas" = 3,
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
            "comgen_per_cat" = c(
                "Sin medidas en la vivienda" = 1,
                "Una o dos medidas en la vivienda" = 2,
                "Tres o más medidas en la vivienda" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "comgen_com_cat" = c(
                "Sin medidas en el barrio" = 1,
                "Una medida en el barrio" = 2,
                "Dos o más medidas en el barrio" = 3,
                "No aplica" = 85,
                "No sabe" = 88,
                "No responde" = 99
            )
        )
    )
}


#' Especificación de etiquetas de las variables secundarias
#'
#' Va dentro de `cfg$ETIQUETAS_SEC`, y se aplica una vez construidas las
#' variables secundarias.
#'
#' @return Igual estructura que [spec_etiquetas_indices()].
spec_etiquetas_secundarias <- function() {
    list(
        variables = c(
            "Indice de desordenes" = "desordenes_ind",
            "Indice de desordenes (rec)" = "desordenes_ind_rec",
            "Indice de incivilidades" = "incivilidades_ind",
            "Indice de incivilidades (rec)" = "incivilidades_ind_rec",
            "Se informa por experiencia personal" = "info_exp_personal",
            "Se informa por otras personas" = "info_otras_personas",
            "Se informa por RRSS" = "info_rrss",
            "Se informa por prensa" = "info_prensa",
            "Se informa por TV" = "info_tv",
            "Nivel educacional (rec)" = "rph_nivel_rec",
            "Edad (rec)" = "rph_edad_rec",
            "Región (rec)" = "enc_region_rec"
        ),
        valores = list(
            "desordenes_ind_rec" = c(
                "Baja percepción de desordenes" = 1,
                "Media percepción de desordenes" = 2,
                "Alta percepción de desordenes" = 3
            ),
            "incivilidades_ind_rec" = c(
                "Baja percepción de incivilidades" = 1,
                "Media percepción de incivilidades" = 2,
                "Alta percepción de incivilidades" = 3
            ),
            "info_exp_personal" = c(
                "Se informa por experiencia personal" = 1,
                "No se informa por experiencia personal" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_otras_personas" = c(
                "Se informa por otras personas" = 1,
                "No se informa por otras personas" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_rrss" = c(
                "Se informa por RRSS" = 1,
                "No se informa por RRSS" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_prensa" = c(
                "Se informa por prensa" = 1,
                "No se informa por prensa" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "info_tv" = c(
                "Se informa por noticias" = 1,
                "No se informa por noticias" = 0,
                "No sabe" = 88,
                "No responde" = 99
            ),
            "rph_nivel_rec" = c(
                "Educación básica o menos" = 1,
                "Educación secundaria" = 2,
                "Educación terciaria" = 3,
                "Sin dato" = 96,
                "Nivel ignorado" = 99
            ),
            "rph_edad_rec" = c(
                "0 a 29 años" = 1,
                "30 a 59 años" = 2,
                "60 años o más" = 3
            ),
            "enc_region_rec" = c(
                "Zona norte" = 1,
                "Zona centro" = 2,
                "Zona sur" = 3,
                "Zona metropolitana" = 4
            )
        )
    )
}

#' Patrones de separación de etiqueta por dimensión
#'
#' Va dentro de `cfg$PATRONES`. Las etiquetas de la ENUSC traen la pregunta y la
#' alternativa en un solo texto ("¿qué tan seguro se siente...? Caminando solo
#' por su barrio"), y cada dimensión las separa con un patrón distinto. Esto
#' declara cuál usar en cada caso.
#'
#' @return Una lista nombrada por dimensión (`emper`, `perper`, `pergen`,
#'   `comper`, `comgen`), cada una con `sep` (para `pattern_verbose`) o
#'   `extraer` (para `extraer_verbose`).
spec_patrones <- function() {
    list(
        emper = list(sep = "\\? "),
        perper = list(sep = "(\\?|en su|en el)\\s*"),
        pergen = list(sep = "(\\?|en su|en el)\\s*"),
        comper = list(extraer = '"([^"]+)"'),
        comgen = list(sep = "(\\?|\\.)\\s*")
    )
}

#' Columnas de código especial de las baterías de `comgen`
#'
#' Las preguntas de opción múltiple guardan "ninguna", "no sabe" y "no responde"
#' como **columnas propias**, estructuralmente idénticas a las de las medidas.
#' Este spec declara cuál es cuál y a qué variable del modelo corresponde cada
#' grupo.
#'
#' @section Por qué existe como declaración y no dentro del `case_when`:
#' [rescatar_no_respuesta()] las usaba escritas a mano, y como no
#' aparecían en `cfg$INDICES`, [construir_metadata()] las reportaba con uso
#' "No se usa". Eso era falso para `_ns` y `_nr`, que son lo único que separa a
#' quien no respondió de quien respondió "ninguna medida", y engañoso para
#' `_na`, cuyo tratamiento es la decisión que originó este repositorio.
#'
#' @section Los tres roles:
#' - `ns` y `nr` **se leen**: estampan los códigos 88 y 99 sobre la variable
#'   categorizada, después de categorizar.
#' - `na` **no se lee, y esa es la decisión**. Quien marca "ninguna medida"
#'   tiene todas las columnas de medidas en 0, así que el conteo le da 0 por
#'   aritmética, sin necesidad de mirar esta columna. Incluirla en la batería
#'   era el error original: contaba como una medida más y "ninguna" nunca daba
#'   cero.
#'
#' @return Una lista nombrada por variable del modelo, con las columnas `ns`,
#'   `nr` y `na` de su batería.
spec_codigos_comgen <- function() {
    list(
        comgen_per_cat = c(
            ns = "comgen_medidas_ns",
            nr = "comgen_medidas_nr",
            na = "comgen_medidas_na"
        ),
        comgen_com_cat = c(
            ns = "comgen_vecinos_medidas_ns",
            nr = "comgen_vecinos_medidas_nr",
            na = "comgen_vecinos_medidas_na"
        )
    )
}

#' Origen de las variables secundarias
#'
#' `cfg$INDICES` cubre la lineage de las variables fuente, pero las secundarias
#' se construyen en `R/vars_secundarias.R` sin pasar por un spec. Se declara acá
#' y se verifica contra los datos: si una columna deja de existir, falla.
#'
#' @return Lista `variable_creada -> columnas de origen`.
spec_secundarias <- function() {
    list(
        desordenes_ind = "p_desordenes_",
        incivilidades_ind = "p_incivilidades_",
        info_exp_personal = "p_fuente_info_",
        info_otras_personas = "p_fuente_info_",
        info_rrss = "p_fuente_info_",
        info_prensa = "p_fuente_info_",
        info_tv = "p_fuente_info_",
        rph_nivel_rec = "rph_nivel",
        rph_edad_rec = "rph_edad",
        enc_region_rec = "enc_region"
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
