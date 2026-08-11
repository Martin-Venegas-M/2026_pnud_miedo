# Insumos para iteración
rec_vars_flat <- list_flatten(rec_vars) # Aplanar lista (dejar todos los elementos como vectores)
results <- list(vars_rec = c(), vars_source = c(), vars_labels = c()) # Crear lista vacia

# Iterar!
results <- reduce(
    seq_along(rec_vars_flat),
    \(acc, i) {
        # Guardar vector de variables fuente
        fuentes <- rec_vars_flat[[i]]

        # Guardar vector de variable recodificada repetida según cantidad de
        # variables fuente
        recodificadas <- rep(names(rec_vars_flat)[i], length(fuentes))

        # Guardar labels de variables fuente
        labs <- enusc %>%
            select(any_of(fuentes)) %>%
            get_label()

        labs <- unname(labs[fuentes])

        # Almacenar iterativamente en el acumulador (acc)
        acc[[1]] <- c(acc[[1]], recodificadas) # Guardame el resultado de la iteración anterior y agregale el de esta iteración...
        acc[[2]] <- c(acc[[2]], fuentes)
        acc[[3]] <- c(acc[[3]], labs)

        acc # Devolver el acumulador
    },
    .init = results
)

# Generar tibble con la metadata
metadata_recode <- tibble::tibble(
    variable_recodificada = results[[1]],
    variables_fuente = results[[2]],
    etiqueta = results[[3]]
) %>%
    # Separar variable recodificada de la categoría especifica para la que se
    # usan x variables fuente (aplica para perper_delito, comgen_medidas_per y
    # comgen_medidas_com)
    separate(
        variable_recodificada,
        into = c("variable_recodificada", "categoria"),
        sep = "_(?=\\d+$)"
    ) %>%
    # Separar la etiqueta por pregunta y situacion concreta (para opción
    # múltiple)
    separate(
        etiqueta,
        into = c("pregunta", "situacion"),
        sep = "(\\?|en su|en el|edificio.)\\s*"
    )
