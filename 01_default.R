# 01_default.R -- Question 4: R's default scatterplot, nothing added.
# Run from the repository root:  Rscript scripts/01_default.R
install.packages(c("readr", "dplyr", "ggplot2", "svglite"))
library(readr)
library(dplyr)
library(ggplot2)

VARIANT <- 1                                   # <- last two digits of reg. no. %% 8
prov <- c(2, 2, 3, 3, 1, 1, 4, 4)[VARIANT + 1] # prov_code of the variant
area <- c(1, 2, 1, 2, 1, 2, 1, 2)[VARIANT + 1] # urban_rural of the variant

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)

earners <- person |>
  select(hhid, age, earn_annual) |>
  inner_join(hh, by = "hhid") |>                       # attach weight, province, area
  filter(age >= 15, age <= 64, earn_annual > 0,        # earners aged 15-64
         prov_code == prov, urban_rural == area)       # my variant only

dir.create("figures", showWarnings = FALSE)
p <- ggplot(earners, aes(age, earn_annual)) + geom_point()   # defaults, untouched
ggsave("figures/default.svg", p)