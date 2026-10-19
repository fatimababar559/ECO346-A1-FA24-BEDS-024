# scripts/02_distribution.R
# Question 2: Weighted histogram of annual education spending (Variant 0: Punjab rural)

library(tidyverse)
library(svglite)
library(scales)

# Exact weighted quantile per assignment specification:
# sort observations by x, compute cumulative share of weight, and
# take the smallest x at which that share reaches or exceeds p.
weighted_quantile_exact <- function(x, w, p) {
  valid <- !is.na(x) & !is.na(w)
  x <- x[valid]
  w <- w[valid]
  ord <- order(x)
  x_sorted <- x[ord]
  w_sorted <- w[ord]
  cum_share <- cumsum(w_sorted) / sum(w_sorted)
  x_sorted[which(cum_share >= p)[1]]
}

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE)

df <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid")

# Filter to Variant 0 (Punjab rural: prov_code == 2, urban_rural == 1) and students (ed_total > 0)
students_all <- df %>%
  filter(
    prov_code == 2,
    urban_rural == 1,
    !is.na(ed_total),
    ed_total > 0
  )

# Exclude students outside [100, 1,000,000] (log10 units 2.0 to 6.0)
students_in_range <- students_all %>%
  filter(ed_total >= 100, ed_total <= 1000000) %>%
  mutate(log10_ed = log10(ed_total))

n_students_all <- nrow(students_all)
n_in_range     <- nrow(students_in_range)
n_excluded     <- n_students_all - n_in_range

# Compute quantiles on all students and on in-range students
w_med_all   <- weighted_quantile_exact(students_all$ed_total, students_all$hhweight, 0.50)
unw_med_all <- weighted_quantile_exact(students_all$ed_total, rep(1, n_students_all), 0.50)
w_p10_all   <- weighted_quantile_exact(students_all$ed_total, students_all$hhweight, 0.10)
w_p90_all   <- weighted_quantile_exact(students_all$ed_total, students_all$hhweight, 0.90)
ratio_all   <- w_p90_all / w_p10_all

w_med_in    <- weighted_quantile_exact(students_in_range$ed_total, students_in_range$hhweight, 0.50)
unw_med_in  <- weighted_quantile_exact(students_in_range$ed_total, rep(1, n_in_range), 0.50)
w_p10_in    <- weighted_quantile_exact(students_in_range$ed_total, students_in_range$hhweight, 0.10)
w_p90_in    <- weighted_quantile_exact(students_in_range$ed_total, students_in_range$hhweight, 0.90)
ratio_in    <- w_p90_in / w_p10_in

cat("\n================ QUESTION 2 FORM NUMBERS ================\n")
cat("Total students (ed_total > 0):          ", n_students_all, "\n")
cat("Students in range [Rs 100 - Rs 1M]:     ", n_in_range, "\n")
cat("Number excluded (< Rs 100 or > Rs 1M):  ", n_excluded, "\n")
cat("--- Computed on all students (ed_total > 0) ---\n")
cat("Weighted Median (Rs):                   ", round(w_med_all), "\n")
cat("Unweighted Median (Rs):                 ", round(unw_med_all), "\n")
cat("Weighted 10th Percentile (Rs):          ", round(w_p10_all), "\n")
cat("Weighted 90th Percentile (Rs):          ", round(w_p90_all), "\n")
cat("90th/10th Ratio (2 decimals):           ", sprintf("%.2f", ratio_all), "\n")
cat("--- Computed on in-range students [100, 1M] ---\n")
cat("Weighted Median (Rs):                   ", round(w_med_in), "\n")
cat("Unweighted Median (Rs):                 ", round(unw_med_in), "\n")
cat("Weighted 10th Percentile (Rs):          ", round(w_p10_in), "\n")
cat("Weighted 90th Percentile (Rs):          ", round(w_p90_in), "\n")
cat("90th/10th Ratio (2 decimals):           ", sprintf("%.2f", ratio_in), "\n")
cat("=========================================================\n\n")

log_med <- log10(w_med_all)
log_p90 <- log10(w_p90_all)

p_dist <- ggplot(students_in_range, aes(x = log10_ed, weight = hhweight)) +
  geom_histogram(
    aes(y = after_stat(density)),
    breaks = seq(2.0, 6.0, by = 0.1),
    fill = "#3182bd",
    color = "white",
    linewidth = 0.25,
    alpha = 0.85
  ) +
  geom_vline(xintercept = log_med, linetype = "dashed", color = "#d95f02", linewidth = 0.8) +
  geom_vline(xintercept = log_p90, linetype = "dashed", color = "#7570b3", linewidth = 0.8) +
  annotate(
    "text",
    x = log_med - 0.05, y = Inf,
    label = paste0("Weighted Median: Rs ", comma(round(w_med_all))),
    vjust = 1.5, hjust = 1, angle = 90,
    color = "#d95f02", fontface = "bold", size = 3.5
  ) +
  annotate(
    "text",
    x = log_p90 - 0.05, y = Inf,
    label = paste0("Weighted 90th Percentile: Rs ", comma(round(w_p90_all))),
    vjust = 1.5, hjust = 1, angle = 90,
    color = "#7570b3", fontface = "bold", size = 3.5
  ) +
  scale_x_continuous(
    limits = c(2.0, 6.0),
    breaks = 2:6,
    labels = c("Rs 100", "Rs 1,000", "Rs 10,000", "Rs 100,000", "Rs 1,000,000")
  ) +
  labs(
    title = paste0(
      "Top-Decile Students in Rural Punjab Spend Rs ",
      comma(round(w_p90_all)), " Annually — ",
      round(w_p90_all / w_med_all, 1), "x the Median"
    ),
    subtitle = "Weighted distribution of annual household education spending per student (PSLM 2019–20)",
    x = "Annual Education Spending per Student (Rupees, log scale)",
    y = "Density per log10 unit",
    caption = paste0(
      "Source: PSLM 2019-20 person and household files. ",
      "Sample: Students (ed_total > 0) in rural Punjab (n = ", comma(n_students_all),
      "; ", n_excluded, " students outside Rs 100 to Rs 1,000,000 excluded). ",
      "Weighted by household survey weights (hhweight)."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.caption = element_text(hjust = 0, color = "grey30", size = 8.5),
    panel.grid.minor = element_blank()
  )

ggsave("figures/distribution.svg", plot = p_dist, width = 8, height = 5)
