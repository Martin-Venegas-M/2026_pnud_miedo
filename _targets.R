library(targets)

tar_option_set(packages = c("tidyverse"))

list(
  tar_target(f0_check, 1 + 1)
)
