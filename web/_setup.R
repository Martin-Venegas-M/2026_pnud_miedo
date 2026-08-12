# Setup compartido de la página (PLAN.md F5.4)
#
# REGLA: el .qmd no calcula. Todo número que aparece en la página nace en un
# target del DAG. Acá solo se lee, se pivotea y se formatea.
#
# Quarto renderiza cada .qmd desde el directorio web/, así que el almacén de
# targets queda un nivel más arriba y hay que apuntarlo explícitamente.

suppressPackageStartupMessages({
    library(dplyr)
    library(tidyr)
    library(targets)
    library(kableExtra)
})

RAIZ <- normalizePath("..", mustWork = TRUE)
STORE <- file.path(RAIZ, "_targets")

stopifnot(
    "No se encuentra el almacén de targets. Correr tar_make() antes de renderizar." = dir.exists(
        STORE
    )
)

#' Leer un target del DAG
leer <- function(nombre) targets::tar_read_raw(nombre, store = STORE)

#' Leer un log del pipeline (los CSV de output/logs/)
leer_log <- function(nombre) {
    readr::read_csv(
        file.path(RAIZ, "output", "logs", paste0(nombre, ".csv")),
        show_col_types = FALSE
    )
}

#' Formato de números al estilo español, para mostrar
n_fmt <- function(x, dec = 0) {
    formatC(
        x,
        format = "f",
        digits = dec,
        big.mark = ".",
        decimal.mark = ","
    )
}

pct_fmt <- function(x, dec = 1) paste0(n_fmt(x, dec), "%")

#' Tabla estándar de la página
#'
#' `kableExtra` + estilos consistentes. Sin interactividad: las tablas
#' interactivas de la página anterior no fueron bien recibidas.
tabla <- function(df, alto = NULL, alinear = NULL, ...) {
    #* `align = NULL` explícito no es lo mismo que omitirlo: kableExtra termina
    #* escribiendo `style="NAposition: sticky"` en los <th>, que es CSS inválido
    #* y deja el encabezado fijo sin funcionar. Se pasa solo si tiene valor.
    args <- list(
        df,
        format.args = list(big.mark = ".", decimal.mark = ","),
        ...
    )
    if (!is.null(alinear)) args$align <- alinear

    k <- do.call(kbl, args) |>
        kable_styling(
            bootstrap_options = c("striped", "hover", "condensed"),
            full_width = TRUE,
            fixed_thead = TRUE
        )

    if (!is.null(alto)) {
        k <- k |> scroll_box(height = alto, extra_css = "overflow-x: auto;")
    }
    k
}

#' Bloque de advertencia de provisionalidad
#'
#' Se usa arriba de cualquier salida que dependa de una decisión abierta. La
#' advertencia va visible, no al pie.
aviso_provisional <- function(decisiones, que_cambia) {
    cat(sprintf(
        "::: {.callout-warning}\n## Provisional\n\nEsta salida depende de %s, que sigue **sin resolver**. %s\n:::\n",
        decisiones,
        que_cambia
    ))
}
