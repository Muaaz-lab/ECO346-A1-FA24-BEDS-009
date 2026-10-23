# 02_distribution.R -- Question 2: weighted histogram of earnings on a log10 scale.
# Run from the repository root:  Rscript scripts/02_distribution.R
# Dependencies must be installed before running offline.
library(readr)
library(dplyr)
library(ggplot2)

VARIANT <- 1                                   # <- last two digits of reg. no. %% 8
prov <- c(2, 2, 3, 3, 1, 1, 4, 4)[VARIANT + 1]
area <- c(1, 2, 1, 2, 1, 2, 1, 2)[VARIANT + 1]

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE) |>
  select(hhid, hhweight, prov_code, urban_rural)

d <- person |>
  select(hhid, age, earn_annual) |>
  inner_join(hh, by = "hhid") |>
  filter(age >= 15, age <= 64, earn_annual > 0,
         prov_code == prov, urban_rural == area)

# Weighted quantile, exactly the paper's definition: sort by x, cumulative weight
# share, smallest x whose share reaches or exceeds p (tiny tolerance for float error).
wq <- function(x, w, p) {
  o <- order(x); x <- x[o]; w <- w[o]
  share <- cumsum(w) / sum(w)
  x[which(share >= p - 1e-12)[1]]
}

x <- d$earn_annual; w <- d$hhweight
n_earners <- nrow(d)
med_w <- wq(x, w, 0.5)
med_u <- median(x)                     # unweighted median
p10 <- wq(x, w, 0.1)
p90 <- wq(x, w, 0.9)
inside <- x >= 1e4 & x <= 1e7
n_excl <- sum(!inside)

cat("earners:", n_earners, "\n")
cat("weighted median:", round(med_w), " unweighted median:", round(med_u), "\n")
cat("p10:", round(p10), " p90:", round(p90), " ratio:", sprintf("%.2f", p90 / p10), "\n")
cat("excluded from histogram:", n_excl, "\n")

# Weighted histogram: bins 0.1 wide in log10 units from 4.0 to 7.0 (30 bins).
# Density per log10 unit = (weight share in the bin) / 0.1.
h <- d[inside, ]
bin <- pmin(floor((round(log10(h$earn_annual), 10) - 4) / 0.1 + 1e-9), 29)  # 0..29; 7.0 goes in last bin
wt <- tapply(h$hhweight, factor(bin, levels = 0:29), sum)
wt[is.na(wt)] <- 0
bins <- data.frame(mid = 4 + 0.1 * (0:29) + 0.05,
                   density = as.numeric(wt) / sum(wt) / 0.1)

rs <- function(v) paste0("Rs ", formatC(round(v), format = "d", big.mark = ","))
ymax <- max(bins$density)

g <- ggplot(bins, aes(mid, density)) +
  geom_col(width = 0.1, fill = "grey60", colour = "white") +
  geom_vline(xintercept = log10(c(med_w, p90)), linetype = "dashed") +
  annotate("text", x = log10(med_w), y = ymax * 1.06, label = paste0("Median\n", rs(med_w)),
           hjust = 1.08, size = 3.5) +
  annotate("text", x = log10(p90), y = ymax * 1.06, label = paste0("90th pct.\n", rs(p90)),
           hjust = -0.08, size = 3.5) +
  scale_x_continuous(breaks = 4:7,
                     labels = c("Rs 10,000", "Rs 100,000", "Rs 1,000,000", "Rs 10,000,000")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(title = paste0("Half of earners make under ", rs(med_w), "; the top tenth make ",
                      rs(p90), " or more"),
       x = "Annual earnings (log scale)", y = "Density per log10 unit",
       caption = paste0("Source: PSLM 2019-20. Sample: earners aged 15-64 with earnings > 0 in my variant (n = ",
                        n_earners, "). Weighted by hhweight. ",
                        n_excl, " earners outside Rs 10,000-10,000,000 are excluded.")) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        plot.title = element_text(face = "bold"), plot.caption = element_text(hjust = 0, size = 8))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/distribution.svg", g, width = 8, height = 5)