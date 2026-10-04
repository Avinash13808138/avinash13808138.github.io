install.packages("tidycensus")
library(tidycensus)
library(tidyverse)

# Set Census API Key
census_api_key("", install = TRUE)


states_of_interest <- c("Alabama","Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", 
                        "Delaware", "District of Columbia", "Florida", "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana",
                        "Maine","Maryland", "Massachusetts", "Michigan", "Minnesota", "Missouri", "Mississippi", "Montana", "Nebraska","Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York",
                        "Montana", "Nebraska","Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York", 
                        "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon",
                        "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota", 
                        "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington", 
                        "West Virginia", "Wisconsin", "Wyoming"
                        )

# Include DC, HI, ID, IL, KY, LA, MS in poll dataset

vars_all <- c(
  pop        = "B01003_001",   # total population
  medage     = "B01002_001",   # median age
  medincome  = "B19013_001",   # median household income
  female = "B01001_026", # or B010
  employed = "B23025_004", # or S2301_C04_001
  white = "B02001_002",
  black = "B02001_003",
  asian = "B02001_005",
  hispanic = "B03001_003",
  college = "B15003_022",
  highschool = "B15003_017",
  age65 = "B01001_020",
  poverty = "B17001_002",
  govworker = "B24080_002",
  gov_fed = "B24080_003", # or B24070_007
  gov_state = "B24080_004", # or B24070_008
  gov_local = "B24080_005", # or B24070_009
  gov_military = "B24080_006", # or B24070_010
  ownhome = "B25003_002", # divided by B25003_001
  totalhomes = "B25003_001",
  uninsured = "B27010_053", # or B27010_053
  unemp = "B23025_005" # or S2301_C05_001
)

state_demog2023 <- get_acs(
  geography = "state",
  variables = vars_all,
  year = 2023,
  survey = "acs1",
  output = "wide",
  key = "deba8af349d24ee7c96b39389eaede82fefdcd1c"
) %>%
  filter(NAME %in% states_of_interest) %>% 
  select(-ends_with("M")) %>% # remove MOE columns. 
  rename_with(~str_remove(.x, "E$")) # remove "E" from end of column names
state_demog2023$statename <- state_demog2023$NAM

state_demog2023$state <- state.abb[match(state_demog2023$statename, state.name)]
state_demog2023 <- state_demog2023 %>% 
  mutate(
    state = ifelse(statename == "District of Columbia", "DC", state)
  )

state_demog2022 <- get_acs(
  geography = "state",
  variables = vars_all,
  year = 2022,
  survey = "acs1",
  output = "wide",
  key = "deba8af349d24ee7c96b39389eaede82fefdcd1c"
) %>%
  filter(NAME %in% states_of_interest) %>% 
  select(-ends_with("M")) %>% # remove MOE columns. 
  rename_with(~str_remove(.x, "E$")) # remove "E" from end of column names


# Get latest ACS data?

