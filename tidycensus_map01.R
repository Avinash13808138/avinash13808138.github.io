# Packages
library(tidycensus)
library(tigris)
library(sf)
library(dplyr)
library(ggplot2)
library(readr)
options(tigris_use_cache = TRUE)
# 1) API key — run ONCE in the console, never in this file
# census_api_key("YOUR_CENSUS_KEY", install = TRUE)
# 2) Explore variables (no `cache` argument — deprecated and ignored)
vars <- load_variables(2024, "acs5")
vars |> dplyr::filter(grepl("^B19", name)) |> dplyr::slice_head(n = 10)
# 3) Parameters (EDIT ME)
state_abbr <- "TX"
geo_level <- "county" # options: state, county, tract, block group
my_vars <- c(income = "B19013_001", # median household income
             pov = "B17001_002", # people below poverty
             povden = "B17001_001") # poverty universe = denominator
year_acs <- 2024
survey <- "acs5"
# 4) Download, wide — one row per area, and the sf class survives
acs_wide <- get_acs(
  geography = geo_level,
  variables = my_vars,
  state = state_abbr,
  year = year_acs,
  survey = survey,
  geometry = TRUE,
  output = "wide"
)

# 5) Derive a rate, and carry its margin of error through
acs_wide <- acs_wide |>
  mutate(pov_rate = povE / povdenE,
         pov_moe = moe_prop(povE, povdenE, povM, povdenM))

# 6) Map (edit titles/theme)
ggplot(acs_wide) +
  geom_sf(aes(fill = incomeE), color = NA) +
  scale_fill_viridis_c(name = "Median HH Income") +
  labs(title = paste0("ACS ", year_acs, " 5-year: Median Income — ",
                      state_abbr, " (", geo_level, ")"),
       caption = "Source: U.S. Census Bureau via tidycensus") +
  theme_minimal() + 
  theme(text = element_text(family = "Palatino"), # drop if not installed
      plot.title = element_text(size = 14, face = "bold"),
      plot.caption = element_text(size = 8),
      legend.position = "inside",
      legend.position.inside = c(0.2, 0.15))
# 7) Table (top/bottom by poverty rate, with MOE)
top10 <- acs_wide |>
  st_drop_geometry() |>
  arrange(desc(pov_rate)) |>
  select(NAME, pov_rate, pov_moe, povE, povM) |>
  slice_head(n = 10)
bottom10 <- acs_wide |>
  st_drop_geometry() |>
  arrange(pov_rate) |>
  select(NAME, pov_rate, pov_moe, povE, povM) |>
  slice_head(n = 10)
top10
bottom10
# 8) Save outputs
write_csv(st_drop_geometry(acs_wide),
          paste0("acs_", state_abbr, "_", year_acs, ".csv"))
