## =============================================================================
## EPPS 6302 Methods of Data Collection and Production
## YouTubeAPI02.R — Collecting YouTube data with the YouTube Data API v3
## Revised 27 October 2026 for tuber 2.0.0.9000 (development version, httr2).
## Replaces YouTubeAPI01.R and the 20 October version of this file.
##
##   Part 0  Install the development version and load
##   Part 1  Credentials: an API key, OAuth, or both?
##   Part 2  Quota: plan before you call
##   Part 3  Find videos: search (expensive) vs. a channel's uploads (cheap)
##   Part 4  Describe videos and channels
##   Part 5  Comments: one video, then many — with a log and a manifest
##   Part 6  From comments to a quanteda corpus
##   Part 7  OAuth: private data (your own account)
##   Part 8  Under the hood: the same request with httr2
##   Part 9  Optional: reply networks with vosonSML
##
## tuber docs: https://gojiplus.github.io/tuber/
## API quota table: https://developers.google.com/youtube/v3/determine_quota_cost
## API policies: https://developers.google.com/youtube/terms/developer-policies
## =============================================================================


## =============================================================================
## Part 0 — Install and load
## =============================================================================
# Once, in the Console:
# install.packages("pak")
# pak::pak(c("soodoku/tuber", "httr2"))   # development version, 2.0.0.9000
#   Name httr2 too: tuber needs httr2 1.1.0 or later but does not say so, and
#   with httr2 1.0.x the install fails with "'req_headers_redacted' is not
#   exported by 'namespace:httr2'". Naming it makes pak update it.
#   The repository moved to gojiplus/tuber; GitHub redirects the old name.
#   If pak cannot resolve it, use pak::pak("gojiplus/tuber") — same package.
# install.packages(c("tidyverse", "quanteda", "quanteda.textstats",
#                    "quanteda.textplots", "jsonlite", "usethis", "httr2"))

library(tuber)
library(tidyverse)
library(quanteda)
library(quanteda.textstats)
library(quanteda.textplots)

packageVersion("tuber")      # 2.0.0.9000 or later
packageVersion("httr2")      # 1.1.0 or later (tested with 1.3.0)
# What changed from older scripts:
#   - Function names (since 2.0.0):
#       get_comment_threads() -> list_comment_threads()
#       get_channel_stats()   -> get_channel_details()
#       get_stats()           -> get_video_stats()
#       get_playlist_items()  -> list_playlist_items()
#   - tuber now talks to YouTube through httr2 only (httr is gone).
#   - OAuth tokens saved by older versions cannot be reused; yt_oauth()
#     says so and signs you in again.
#   - Keys and tokens travel in redacted headers: a printed request or an
#     error message no longer shows them.


## =============================================================================
## Part 1 — Credentials: an API key, OAuth, or both?
##
## Two credentials, two jobs. Every tuber function uses exactly one per call.
##
##   | You want to...                                  | Credential        |
##   |-------------------------------------------------|-------------------|
##   | search, videos, channels, playlists, comments   | API key (default, |
##   |   — anything PUBLIC                             |   auth = "key")   |
##   | your own channel, videos, subscriptions,        | OAuth (no `auth`  |
##   |   captions; anything that WRITES to YouTube     |   argument)       |
##   | a public read, but signed in as yourself        | OAuth, by passing |
##   |                                                 |   auth = "token"  |
##
## So: for this course's collection work an API KEY ALONE is enough.
## OAuth alone could also do public reads, but you would have to add
## auth = "token" to every call. You need BOTH only when one script mixes
## default public reads with private data or writes — Part 7 below.
## Both credentials come from the same Google Cloud project and draw on the
## same daily quota.
## =============================================================================

## 1a. The API key (required for this course)
##   1. https://console.cloud.google.com/ -> new project ("epps6302-youtube")
##   2. APIs & Services -> Library -> "YouTube Data API v3" -> Enable
##   3. APIs & Services -> Credentials -> Create credentials -> API key
##   4. Edit the key -> API restrictions -> Restrict key -> YouTube Data API v3

## 1b. Store it in your USER .Renviron, never in a script
##   usethis::edit_r_environ()          # opens ~/.Renviron
##   add one line:
##       YOUTUBE_KEY=AIza...your-key...
##   save, then Session -> Restart R (R reads the file only at start-up).
##
##   WHICH .Renviron? At start-up R reads .Renviron in the WORKING DIRECTORY
##   if there is one — and then IGNORES ~/.Renviron entirely. In an RStudio
##   project with its own .Renviron, your home-folder key never loads.
##   Either put the key in the project's .Renviron too, or delete that file.
##   tuber reads YOUTUBE_KEY from the environment by itself; there is nothing
##   to call. yt_set_key() sets it for the current session only.

nzchar(Sys.getenv("YOUTUBE_KEY"))   # TRUE? You are ready. Do not print the key.

## FALSE? Find out which file R is (not) reading — without printing the key:
# file.exists(".Renviron")                     # TRUE: this file replaces ~/.Renviron
# file.exists("~/.Renviron")                   # FALSE: wrong place or wrong name
# list.files("~", pattern = "Renviron", all.files = TRUE)  # ".Renviron.txt"?
# Sys.getenv("R_ENVIRON_USER")                 # set? R reads that file instead
# sub("=.*", "=<hidden>", readLines("~/.Renviron"))       # names typed right?

readRenviron("~/.Renviron")                  # load it now, then check again

# A PROJECT-level .Renviron (in the website folder) must be gitignored first —
# your repository is public:
# usethis::use_git_ignore(".Renviron")

## 1c. The OAuth client (only for Part 7)
##   1. Same project -> Google Auth Platform (OAuth consent screen):
##        app name, support email; Audience: External; leave it in "Testing"
##   2. Audience -> Test users -> add YOUR Google account
##   3. Clients -> Create client -> Application type: **Desktop app**
##        (not "Web application": a desktop client accepts the local redirect
##        tuber uses, so there is no redirect URI to register and no
##        "Error 400: redirect_uri_mismatch")
##   4. Copy the Client ID and Client secret into ~/.Renviron:
##        YT_CLIENT_ID=1234-abc.apps.googleusercontent.com
##        YT_CLIENT_SECRET=GOCSPX-...
##   Restart R, then check without printing:
c(key    = nzchar(Sys.getenv("YOUTUBE_KEY")),
  id     = nzchar(Sys.getenv("YT_CLIENT_ID")),
  secret = nzchar(Sys.getenv("YT_CLIENT_SECRET")))


## =============================================================================
## Part 2 — Quota: plan before you call
##
## Default allocation per Google Cloud project, reset at midnight Pacific:
##   search.list  — its own bucket of 100 calls a day (50 results per call)
##   everything else — 10,000 units a day; most reads cost 1 unit per page
##     videos.list, channels.list, playlistItems.list   1 unit per page of 50
##     commentThreads.list, comments.list               1 unit per page of 100
##     captions.list                                    50 units
##
## So: yt_search(max_results = 500) spends 10 of your 100 daily searches;
## 5,000 comments cost about 50 units. Search is the scarce resource.
## =============================================================================

yt_get_quota_usage()    # tuber's local estimate for this R session


## =============================================================================
## Part 3 — Find videos (API key)
## =============================================================================

## 3a. Search: US midterm elections
mtelection <- yt_search(term             = "US midterm election",
                   published_after  = "2026-09-01T00:00:00Z",
                   published_before = "2026-10-28T00:00:00Z",
                   order            = "relevance",   # also: "viewCount", "date"
                   max_results      = 100)           # 2 search calls
glimpse(mtelection)    # video_id, published_at, title, description, channel_id, ...
attr(mtelection, "total_results")    # what YouTube says exists
nrow(mtelection)                     # what you got

mtelection |> count(channel_title, sort = TRUE) |> head(15)

## Search results are a RANKING, not a sample. Change `order` and compare:
mtelection_views <- yt_search(term = "US midterm election",
                              published_after  = "2026-09-01T00:00:00Z",
                              published_before = "2026-10-28T00:00:00Z",
                         order = "viewCount", max_results = 100)
length(intersect(mtelection$video_id, mtelection_views$video_id))   # how much overlap?

## 3b. A channel's uploads: the cheap route (playlistItems, 1 unit per 50)
## The channel ID starts with "UC". Find it on the channel page (View page
## source, search "channelId") or from the channel_id column above.
nbc_id <- "UCeY0bbntWzzVIaj2z3QigXg"     # NBC News

nbc_channel <- get_channel_details(channel_ids = nbc_id)
nbc_channel |> select(title, subscriber_count, video_count, view_count)

nbc_videos <- list_channel_videos(nbc_id, max_results = 200) |>   # 4 units
  mutate(date = as.Date(video_published_at)) |>
  arrange(desc(date))
head(nbc_videos$title)

## Do NOT use yt_search(term = "", channel_id = ...) to list a channel: it costs
## search calls and returns at most 500 videos. list_channel_videos() is
## cheaper and complete — but newest first: reaching a year back on a channel
## that posts 30 videos a day takes ~220 units. Check how far back you got:
range(nbc_videos$date)


## =============================================================================
## Part 4 — Describe videos and channels (API key)
## =============================================================================
vids <- mtelection |> distinct(video_id) |> pull(video_id)

stats   <- get_video_stats(vids, include_content_details = TRUE)  # 50 ids per unit
details <- get_video_details(vids[1:3], part = c("snippet", "statistics"))

video_info <- mtelection |>
  select(video_id, title, channel_id, channel_title, published_at) |>
  left_join(stats, by = "video_id")

video_info |>
  arrange(desc(view_count)) |>
  select(channel_title, title, view_count, comment_count) |>
  head(10)

## Which channels? Subscriber counts are rounded by YouTube — say so.
chan <- get_channel_details(channel_ids = unique(mtelection$channel_id))
chan |> select(title, country, subscriber_count, video_count) |>
  arrange(desc(subscriber_count))


## =============================================================================
## Part 5 — Comments (API key)
## =============================================================================

## 5a. One video, top-level comments only (1 unit per 100)
one_vid <- video_info |> filter(comment_count > 0) |> slice_max(view_count) |>
  pull(video_id)

threads <- list_comment_threads(video_id    = one_vid,
                                text_format = "plainText",
                                max_results = 200)
glimpse(threads)

## 5b. Same video, with replies. ALWAYS set max_results: NULL means "all".
comments <- get_all_comments(one_vid, max_results = 500)
glimpse(comments)    # comment_id, parent_id, video_id, author_name,
                     # text_original, like_count, published_at, ...
comments |> count(is_reply = !is.na(parent_id))

## 5c. Many videos, politely, with a log. Comments may be disabled, the video
## may be gone, or the quota may run out — record each outcome, do not stop.
dir_yt <- "data/youtube"
dir.create(dir_yt, recursive = TRUE, showWarnings = FALSE)

## Disabled comments and empty sections arrive as WARNINGS (classes
## tuber_comments_disabled, tuber_no_comments) with an empty data frame;
## other failures are errors. Record which.
collect_comments <- function(video_id, n_max = 300) {
  status <- "ok"
  out <- tryCatch(
    withCallingHandlers(
      get_all_comments(video_id, max_results = n_max),
      tuber_comments_disabled = function(w) {
        status <<- "disabled"; invokeRestart("muffleWarning")
      },
      tuber_no_comments = function(w) {
        if (status == "ok") status <<- "none"; invokeRestart("muffleWarning")
      }),
    error = function(e) e)
  Sys.sleep(1)                                   # be polite
  if (inherits(out, "error")) {
    return(list(data = NULL,
                log  = tibble(video_id, status = "error", n = 0L,
                              message = conditionMessage(out))))
  }
  list(data = as_tibble(out),
       log  = tibble(video_id, status, n = nrow(out), message = NA_character_))
}

targets <- video_info |>
  filter(comment_count > 0) |>
  slice_max(view_count, n = 10) |>
  pull(video_id)

runs <- map(targets, collect_comments, .progress = TRUE)

yt_log <- map(runs, "log") |> list_rbind() |>
  mutate(collected_at = format(Sys.time(), tz = "UTC", usetz = TRUE))
yt_comments <- map(runs, "data") |> list_rbind() |>
  left_join(video_info |> select(video_id, channel_title, video_title = title),
            by = "video_id")

write_csv(yt_log, file.path(dir_yt, "collection_log.csv"))
write_rds(yt_comments, file.path(dir_yt, "comments.rds"))   # data/ is gitignored

## 5d. Manifest: how this was collected — the query, not the key
manifest <- list(
  source       = "YouTube Data API v3 via tuber",
  tuber        = as.character(packageVersion("tuber")),
  credential   = "API key (public data only)",
  collected_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  search       = list(term = "US midterm elections", order = "relevance",
                      published_after  = "2026-09-01T00:00:00Z",
                      published_before = "2026-10-28T00:00:00Z",
                      returned = nrow(mtelection),
                      total_reported = attr(mtelection, "total_results")),
  selection    = "10 most-viewed results with comments enabled; max 300 comments each",
  n_videos     = length(targets),
  n_comments   = nrow(yt_comments),
  retention    = "Delete or refresh within 30 days (YouTube API Developer Policies III.E.4)",
  delete_by    = format(Sys.Date() + 30)
)
jsonlite::write_json(manifest, file.path(dir_yt, "manifest.json"),
                     auto_unbox = TRUE, pretty = TRUE)


## =============================================================================
## Part 6 — From comments to a quanteda corpus
## =============================================================================
corp_yt <- yt_comments |>
  mutate(is_reply = !is.na(parent_id),
         date     = as.Date(published_at)) |>
  select(comment_id, text_original, video_id, channel_title,
         is_reply, like_count, date) |>
  corpus(docid_field = "comment_id", text_field = "text_original")

summary(corp_yt, n = 5)

toks_yt <- tokens(corp_yt, remove_punct = TRUE, remove_url = TRUE,
                  remove_symbols = TRUE) |>
  tokens_tolower() |>
  tokens_remove(stopwords("en"))
dfm_yt <- dfm(toks_yt)

topfeatures(dfm_yt, 30)
kwic(tokens(corp_yt), pattern = c("xi", "tariff*", "taiwan"), window = 6) |>
  head(20)

## Which words distinguish the comments under one channel's videos?
top_channel <- names(sort(table(docvars(corp_yt, "channel_title")),
                          decreasing = TRUE))[1]
dfm_yt |>
  dfm_group(groups = channel_title) |>
  textstat_keyness(target = top_channel) |>
  textplot_keyness(n = 15)


## =============================================================================
## Part 7 — OAuth: private data (your own account)
##
## Needs the OAuth client from 1c. Run interactively, in RStudio: a browser
## opens, you choose your Google account, and Google sends the answer back to
## R on localhost. "Google hasn't verified this app" is expected for your own
## app in Testing: Advanced -> Go to <app name>.
##
## Ask for the narrowest scope that does the job. "own_account_readonly"
## reads your account and cannot change anything. The default, "ssl",
## can manage your account — upload, delete, comment.
## =============================================================================
tok_ro <- file.path(tools::R_user_dir("tuber", "cache"), "token-readonly.rds")

yt_oauth(Sys.getenv("YT_CLIENT_ID"), Sys.getenv("YT_CLIENT_SECRET"),
         scope = "own_account_readonly", token = tok_ro)
yt_authorized()           # TRUE: a token is loaded for this session
## Always pass the ID and secret, even when a token is cached: tuber keeps the
## client so it can refresh an expired token without a new browser login.
## Never save the token inside your project folder; the default lives in
## tools::R_user_dir("tuber", "cache").

## 7a. OAuth-only functions — no `auth` argument
my_subs <- list_subscriptions(mine = TRUE, max_results = 50)   # 1 unit
my_subs |> select(title, subscribed_channel_id) |> head()
## Your subscriptions are private: no API key can read them. That is the
## line between the two credentials.

me <- get_my_channel()         # zero rows if your account has no channel
if (nrow(me) > 0) {
  my_vids <- list_my_videos(max_results = 25)
  my_vids |> select(title, video_published_at)
}

## 7b. A public read, signed in as yourself
nbc_token <- get_channel_details(channel_ids = nbc_id, auth = "token")
identical(nbc_token$subscriber_count, nbc_channel$subscriber_count)
## Same data, different credential. With a key AND a token loaded, each call
## uses the key unless it is OAuth-only or you pass auth = "token".

## 7c. Captions — owner-only, and a wider scope
## captions.list needs the "ssl" scope and costs 50 units; download_caption()
## works only for videos your account owns (or manages as a partner).
## A different scope needs a different token file:
# tok_ssl <- file.path(tools::R_user_dir("tuber", "cache"), "token-ssl.rds")
# yt_oauth(Sys.getenv("YT_CLIENT_ID"), Sys.getenv("YT_CLIENT_SECRET"),
#          scope = "ssl", token = tok_ssl)
# tracks <- list_captions(my_vids$video_id[1])
# cap    <- download_caption(tracks$caption_id[1], format = "srt", as_raw = FALSE)

## 7d. Sign out of this session (the cached file stays until you delete it)
options(google_token = NULL)
# file.remove(tok_ro)          # forget the token completely


## =============================================================================
## Part 8 — Under the hood: the same request with httr2
## tuber 2.0.0.9000 builds exactly this: the key in an `x-goog-api-key`
## header, redacted, rather than `key=` in the URL.
## =============================================================================
library(httr2)

req <- request("https://www.googleapis.com/youtube/v3/commentThreads") |>
  req_url_query(part = "snippet", videoId = one_vid, maxResults = 100,
                order = "relevance", textFormat = "plainText") |>
  req_headers_redacted("x-goog-api-key" = Sys.getenv("YOUTUBE_KEY"))
req                       # the key prints as <REDACTED>

resp <- req |> req_perform() |> resp_body_json()

names(resp)               # kind, etag, nextPageToken, pageInfo, items
resp$nextPageToken        # pass as pageToken= for the next page: 1 more unit
tibble(item = resp$items) |>
  hoist(item,
        text      = c("snippet", "topLevelComment", "snippet", "textOriginal"),
        likes     = c("snippet", "topLevelComment", "snippet", "likeCount"),
        n_replies = c("snippet", "totalReplyCount")) |>
  select(-item)


## =============================================================================
## Part 9 — Optional: who replies to whom (vosonSML)
## Same key, same quota; returns an actor network ready for igraph.
## =============================================================================
# install.packages(c("vosonSML", "igraph"))
# library(vosonSML)
# yt_auth  <- Authenticate("youtube", apiKey = Sys.getenv("YOUTUBE_KEY"))
# yt_data  <- Collect(yt_auth, videoIDs = targets[1:3], maxComments = 300,
#                     writeToFile = FALSE, verbose = TRUE)
# actor_net <- Create(yt_data, "actor") |> Graph()
# igraph::vcount(actor_net); igraph::ecount(actor_net)


## =============================================================================
## Troubleshooting
##   "Please set a YouTube API key"  — YOUTUBE_KEY empty. Usually a project
##                                     .Renviron that replaces ~/.Renviron, a
##                                     file saved as .Renviron.txt, a typo in
##                                     the name, or R not restarted. Run the
##                                     checks under 1b.
##   400 API key not valid           — key mistyped or truncated when pasted.
##   403 accessNotConfigured         — YouTube Data API v3 not enabled for
##                                     the project that owns the key.
##   403 quotaExceeded               — out of units or search calls; wait for
##                                     midnight Pacific.
##   "Please get a token using yt_oauth()" — an OAuth-only call, or
##                                     auth = "token", with no token loaded.
##   "app_id and app_secret are required" — no cached token; check
##                                     YT_CLIENT_ID / YT_CLIENT_SECRET.
##   Error 403: access_denied in the browser — your account is not a test
##                                     user on the consent screen.
##   Error 400: redirect_uri_mismatch — client type is "Web application";
##                                     create a "Desktop app" client.
##   "access token has expired and cannot be refreshed" — you called
##                                     yt_oauth() without ID and secret; call
##                                     it again with both.
##   Old token rejected after updating tuber — expected; httr tokens cannot
##                                     be reused, sign in once more.
##   Refusing to write .httr-oauth   — do not pass token = ".httr-oauth";
##                                     use the default path.
##   "could not find function get_comment_threads" — renamed in tuber 2.0.
## =============================================================================
