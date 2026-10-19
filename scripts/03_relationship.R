# scripts/03_relationship.R
# Question 3: Weighted literacy rate against age band by sex (Variant 0: Punjab rural)

library(tidyverse)
library(svglite)

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE)

df <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid")

lit_sample <- df %>%
  filter(
    prov_code == 2,
    urban_rural == 1,
    age >= 10, age <= 64,
    !is.na(literate),
    sex %in% c(1, 2)
  ) %>%
  mutate(
    band_start = floor((age - 10) / 5) * 5 + 10,
    band_end   = band_start + 4,
    age_band   = paste0(band_start, "-", band_end),
    midpoint   = band_start + 2,
    sex_label  = if_else(sex == 1, "Men", "Women")
  )

band_stats <- lit_sample %>%
  group_by(age_band, midpoint, sex_label) %>%
  summarise(
    n_unweighted = n(),
    lit_rate     = 100 * sum(hhweight * literate) / sum(hhweight),
    is_thin      = n() < 30,
    .groups      = "drop"
  )

band_wide <- band_stats %>%
  select(age_band, midpoint, sex_label, n_unweighted, lit_rate) %>%
  pivot_wider(
    names_from  = sex_label,
    values_from = c(n_unweighted, lit_rate)
  ) %>%
  mutate(gap = lit_rate_Men - lit_rate_Women) %>%
  arrange(midpoint)

max_gap_row <- band_wide %>% slice_max(order_by = abs(gap), n = 1, with_ties = FALSE)

cat("\n================ BAND TABLE FOR README.md ================\n")
cat("| Age Band | Midpoint | Men (n) | Men Literacy (%) | Women (n) | Women Literacy (%) | Gap (M - W, pp) |\n")
cat("|----------|----------|---------|------------------|-----------|--------------------|-----------------|\n")
for (i in seq_len(nrow(band_wide))) {
  r <- band_wide[i, ]
  cat(sprintf(
    "| %s | %d | %d | %.1f%% | %d | %.1f%% | %.1f |\n",
    r$age_band, r$midpoint,
    r$n_unweighted_Men, r$lit_rate_Men,
    r$n_unweighted_Women, r$lit_rate_Women,
    r$gap
  ))
}
cat("==========================================================\n\n")

b_15_19 <- band_wide %>% filter(age_band == "15-19")
b_55_59 <- band_wide %>% filter(age_band == "55-59")

cat("================ QUESTION 3 FORM NUMBERS ================\n")
cat(sprintf("Women aged 15-19 literacy rate: %.1f%%\n", b_15_19$lit_rate_Women))
cat(sprintf("Men aged 15-19 literacy rate:   %.1f%%\n", b_15_19$lit_rate_Men))
cat(sprintf("Women aged 55-59 literacy rate: %.1f%%\n", b_55_59$lit_rate_Women))
cat(sprintf("Men aged 55-59 literacy rate:   %.1f%%\n", b_55_59$lit_rate_Men))
cat(sprintf("Band with largest gap:          %s (Gap: %.1f percentage points)\n",
            max_gap_row$age_band, max_gap_row$gap))
cat("=========================================================\n\n")

end_labels <- band_stats %>% filter(midpoint == 62)

p_rel <- ggplot(band_stats, aes(x = midpoint, y = lit_rate, color = sex_label, group = sex_label)) +
  annotate(
    "segment",
    x = max_gap_row$midpoint, xend = max_gap_row$midpoint,
    y = max_gap_row$lit_rate_Women, yend = max_gap_row$lit_rate_Men,
    color = "grey35", linetype = "dotted", linewidth = 0.8
  ) +
  annotate(
    "label",
    x = max_gap_row$midpoint,
    y = (max_gap_row$lit_rate_Men + max_gap_row$lit_rate_Women) / 2,
    label = sprintf("Largest gap (%s):\n%.1f pp", max_gap_row$age_band, max_gap_row$gap),
    size = 3.1, fill = "white", color = "grey20", label.size = 0.25
  ) +
  geom_line(linewidth = 1) +
  geom_point(aes(shape = is_thin, fill = sex_label), size = 3, stroke = 1.1) +
  geom_text(
    data = end_labels,
    aes(label = paste0(sex_label, " (", sprintf("%.1f%%", lit_rate), ")")),
    hjust = -0.12, vjust = 0.5, fontface = "bold", size = 3.6
  ) +
  scale_color_manual(values = c("Men" = "#1f78b4", "Women" = "#e31a1c")) +
  scale_fill_manual(values = c("Men" = "#1f78b4", "Women" = "#e31a1c")) +
  scale_shape_manual(values = c("FALSE" = 19, "TRUE" = 1)) +
  scale_x_continuous(
    breaks = seq(12, 62, by = 5),
    limits = c(10, 71),
    labels = unique(band_wide$age_band)
  ) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, by = 20)) +
  labs(
    title = "Literacy Rises Sharply in Younger Cohorts in Rural Punjab, Narrowing the Gender Gap",
    subtitle = "Weighted literacy rate (%) by 5-year age band and sex, plotted at band midpoints",
    x = "Age Band (plotted at 5-year midpoints: 12, 17, ..., 62)",
    y = "Weighted Literacy Rate (%)",
    caption = paste0(
      "Source: PSLM 2019-20 person and household files. ",
      "Sample: Persons aged 10-64 with non-missing literacy in rural Punjab (n = ",
      scales::comma(nrow(lit_sample)), "). ",
      "Weighted by hhweight. Hollow markers indicate thin cells with fewer than 30 unweighted observations."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 12),
    plot.caption = element_text(hjust = 0, color = "grey30", size = 8.5),
    panel.grid.minor = element_blank()
  )

ggsave("figures/relationship.svg", plot = p_rel, width = 8.5, height = 5.2)
