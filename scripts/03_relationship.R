# 03_relationship.R -- Question 3: earnings vs age, with weighted band means.
# Run from the repository root:  Rscript scripts/03_relationship.R

library(readr)
library(dplyr)
library(ggplot2)

VARIANT <- 1                                   # <- last two digits of reg. no. %% 8
prov <- c(2, 2, 3, 3, 1, 1, 4, 4)[VARIANT + 1]
area <- c(1, 2, 1, 2, 1, 2, 1, 2)[VARIANT + 1]

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)

# Earners aged 15-64 with earnings > 0, in my variant, with household weights attached.
d <- person |>
  select(hhid, age, earn_annual) |>
  inner_join(hh, by = "hhid") |>
  filter(age >= 15, age <= 64, earn_annual > 0,
         prov_code == prov, urban_rural == area)

# Band table: five-year bands, plotted at the midpoint; thin = fewer than 30 earners.
bands <- d |>
  mutate(band_start = 5 * (age %/% 5)) |>
  group_by(band_start) |>
  summarise(n = n(),
            wmean = sum(hhweight * earn_annual) / sum(hhweight),   # weighted mean
            .groups = "drop") |>
  mutate(band = paste0(band_start, "-", band_start + 4),
         mid = band_start + 2,
         thin = n < 30,
         wmean = round(wmean))                                     # whole rupees

dir.create("figures", showWarnings = FALSE)
write_csv(bands |> select(band, n, wmean), "figures/band_table_R.csv")
print(bands |> select(band, n, wmean, thin))

top <- bands |> slice_max(wmean, n = 1)        # band with the highest weighted mean
rs <- function(v) paste0("Rs ", formatC(round(v), format = "d", big.mark = ","))
n_off <- sum(d$earn_annual < 1e4 | d$earn_annual > 1e7)   # points outside the axis range

caption <- paste0("Source: PSLM 2019-20. Sample: earners aged 15-64 with earnings > 0 in my variant (n = ",
                  nrow(d), "). Weighted by hhweight (band means only). ",
                  "Hollow markers: band with fewer than 30 earners. ",
                  n_off, " points outside the axis range are not shown.")
caption <- paste(strwrap(caption, width = 110), collapse = "\n")   # wrap so it isn't cut off

set.seed(346)                                  # fixed seed: same jitter every run
g <- ggplot() +
  # individual earners: faint, jittered sideways only (age is whole years)
  geom_point(data = d, aes(age, earn_annual), colour = "grey40", alpha = 0.15, size = 1,
             position = position_jitter(width = 0.4, height = 0)) +
  # weighted band means: line + solid markers (hollow when the band is thin)
  geom_line(data = bands, aes(mid, wmean), colour = "#c0392b", linewidth = 0.9) +
  geom_point(data = filter(bands, !thin), aes(mid, wmean), colour = "#c0392b", size = 3.5) +
  geom_point(data = filter(bands, thin), aes(mid, wmean), colour = "#c0392b",
             shape = 21, fill = "white", stroke = 1.2, size = 3.5) +
  # label the peak band directly
  annotate("label", x = top$mid, y = top$wmean * 1.9,
           label = paste0("Highest: ages ", top$band, "\n", rs(top$wmean)), size = 3.5) +
  scale_y_log10(limits = c(1e4, 1e7), breaks = 10^(4:7),
                labels = c("Rs 10,000", "Rs 100,000", "Rs 1,000,000", "Rs 10,000,000")) +
  scale_x_continuous(breaks = seq(15, 65, 5), limits = c(14.5, 64.5)) +
  labs(title = paste0("Mean earnings rise with age and peak at ", top$band),
       x = "Age (years)", y = "Annual earnings (log scale)", caption = caption) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"),
        plot.caption = element_text(hjust = 0, size = 8))

ggsave("figures/relationship.svg", g, width = 8, height = 5)