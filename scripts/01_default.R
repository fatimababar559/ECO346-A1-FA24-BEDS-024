# scripts/01_default.R
# Question 4: Default untouched scatterplot of literate against age for Variant 0 (Punjab rural)

library(tidyverse)
library(svglite)

person <- read_csv("data/pslm_person_subset.csv", show_col_types = FALSE)
hh     <- read_csv("data/pslm_hh_subset.csv", show_col_types = FALSE)

df <- person %>%
  left_join(hh %>% select(hhid, hhweight, prov_code, urban_rural), by = "hhid")

# Variant 0: Punjab (prov_code == 2) & Rural (urban_rural == 1), aged 10-64, non-missing literate
lit_sample <- df %>%
  filter(
    prov_code == 2,
    urban_rural == 1,
    age >= 10, age <= 64,
    !is.na(literate)
  )

# Exact default plot required by Question 4
p_default <- ggplot(lit_sample, aes(age, literate)) + geom_point()

dir.create("figures", showWarnings = FALSE)
ggsave("figures/default.svg", plot = p_default, width = 7, height = 5)
cat("Successfully saved figures/default.svg (Sample size n =", nrow(lit_sample), ")\n")
