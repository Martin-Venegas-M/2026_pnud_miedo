# Quarto lanza R desde web/, así que R busca acá su .Rprofile y no encuentra el
# renv del proyecto, que vive un nivel más arriba.
#
# RENV_PROJECT tiene que fijarse ANTES de sourcear activate.R: sin eso, renv
# deduce el proyecto desde getwd(), concluye que el proyecto es web/, y arranca
# una biblioteca nueva y vacía acá adentro.
Sys.setenv(RENV_PROJECT = normalizePath(".."))
source("../renv/activate.R")
