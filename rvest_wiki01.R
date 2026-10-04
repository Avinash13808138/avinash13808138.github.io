## EPPS 6302 Methods of Data Collection and Production
## Web scraping 1 — static pages with rvest                     rvest_wiki01.R
##
## Three targets, in order of increasing honesty about what scraping is for:
##   1. a sandbox built to be scraped        (practice, zero ambiguity)
##   2. a Wikipedia table                    (the classic exercise)
##   3. the same numbers from an API         (what you should have done)

# install.packages(c("rvest", "dplyr", "tidyr", "stringr",
#                    "readr", "polite", "janitor", "WDI"))
#

library(rvest)
library(dplyr)
library(stringr)
library(readr)

## ---- 0. Ask permission first ----------------------------------------------
## Always before the first request. robotstxt::paths_allowed() returns TRUE or
## FALSE for the exact path you intend to fetch.

# robotstxt::paths_allowed("https://en.wikipedia.org/wiki/List_of_countries_by_foreign-exchange_reserves")

## ---- 1. The sandbox: books.toscrape.com ------------------------------------
## Built and published for scraping practice. 1,000 books, 50 pages, no
## JavaScript. Learn the verbs here before you point them at anyone's server.

books_pg <- read_html("https://books.toscrape.com/catalogue/page-1.html")

books <- tibble(
  title  = books_pg |> html_elements("article.product_pod h3 a") |> html_attr("title"),
  price  = books_pg |> html_elements("article.product_pod p.price_color") |> html_text2(),
  rating = books_pg |> html_elements("article.product_pod p.star-rating") |>
             html_attr("class") |> str_remove("star-rating ")
) |>
  mutate(price_gbp = parse_number(price))

head(books)

## ---- 2. The Wikipedia table -----------------------------------------------
## html_table() does the parsing. The work is everything after it.

wiki_url <- paste0("https://en.wikipedia.org/wiki/",
                   "List_of_countries_by_foreign-exchange_reserves")

wiki_pg <- read_html(wiki_url)

## Never assume the table you want is [[1]]. Look first.
tabs <- wiki_pg |> html_elements("table.wikitable")
length(tabs)                      # how many candidates?
tabs |> html_table() |> lapply(\(x) dim(x))

reserves_raw <- tabs[[1]] |> html_table()
glimpse(reserves_raw)

## Clean-up. Wikipedia tables arrive with footnote markers, thin spaces,
## multi-row headers and a stray total row. Expect to redo this when the
## article is edited — which is the point of the exercise.
reserves <- reserves_raw |>
  janitor::clean_names() |>
  mutate(across(where(is.character),
                ~ .x |>
                  str_remove_all("\\[.*?\\]") |>   # [1], [note 2]
                  str_squish())) |>
  filter(!str_detect(country_or_region, regex("total|world", ignore_case = TRUE)))

## ---- 3. The same quantity, from an API -------------------------------------
## Foreign reserves are published by the World Bank as FI.RES.TOTL.CD,
## "Total reserves (includes gold, current US$)". One call, versioned,
## documented, and identical for whoever runs it.

# library(WDI)
# reserves_api <- WDI(indicator = "FI.RES.TOTL.CD",
#                     start = 2015, end = 2024, extra = TRUE)
# head(reserves_api)

## ---- 4. Cache what you pulled ----------------------------------------------
write_csv(reserves, paste0("reserves_wiki_", Sys.Date(), ".csv"))

## ---- 5. The question this script exists to raise ---------------------------
## Compare 2 and 3. Same concept, two data-generating processes:
##   - Wikipedia: edited by volunteers, sourced from many places, no schema,
##     no versioning, no uncertainty, changes without notice
##   - World Bank: one compiler, documented methodology, stable indicator code
## Scraping was the wrong tool here. Knowing when it is the *only* tool is the
## skill this course is actually teaching.
