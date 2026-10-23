# 01_default.R — Question 4: the unmodified default scatterplot.
# Run from the repository root: Rscript scripts/01_default.R
# Required packages must already be installed; this script never downloads them.
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

VARIANT <- 1L
prov <- c(2, 2, 3, 3, 1, 1, 4, 4)[VARIANT + 1L]
area <- c(1, 2, 1, 2, 1, 2, 1, 2)[VARIANT + 1L]

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)

earners <- person |>
  select(hhid, age, earn_annual) |>
  inner_join(hh, by = "hhid") |>
  filter(age >= 15, age <= 64, earn_annual > 0,
         prov_code == prov, urban_rural == area)

dir.create("figures", showWarnings = FALSE)
p <- ggplot(earners, aes(age, earn_annual)) + geom_point()
ggsave("figures/default.svg", p)
