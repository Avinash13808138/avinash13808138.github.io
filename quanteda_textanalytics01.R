# Sample program for using quanteda for text modeling and analysis
# Documentation: vignette("quickstart", package = "quanteda")
# Website: https://quanteda.io/


install.packages(c("quanteda", "quanteda.textmodels", "quanteda.textplots", "readr", "ggplot2", "sentimentr", "syuzhet", "reshape2"))

library(quanteda)
library(quanteda.textmodels)
library(quanteda.textplots)
library(readr)
library(ggplot2)

# Twitter data about President Biden and Xi summit in Novemeber 2021
# Do some background search/study on the event
# 
summit <- read_csv("https://raw.githubusercontent.com/datageneration/datamethods/master/textanalytics/summit_11162021.csv")
View(summit)

sum_twt = summit$text
toks = tokens(sum_twt)
sumtwtdfm <- dfm(toks)
class(toks)

# Latent Semantic Analysis 
## (https://quanteda.io/reference/textmodel_lsa.html)

sum_lsa <- textmodel_lsa(sumtwtdfm, nd=4,  margin = c("both", "documents", "features"))
summary(sum_lsa)
head(sum_lsa$docs)
class(sum_lsa)

tweet_dfm <- tokens(sum_twt, remove_punct = TRUE) %>%
  dfm()
head(tweet_dfm)

tag_dfm <- dfm_select(tweet_dfm, pattern = "#*")
toptag <- names(topfeatures(tag_dfm, 50))
head(toptag, 10)
library("quanteda.textplots")
tag_fcm <- fcm(tag_dfm)
head(tag_fcm)
topgat_fcm <- fcm_select(tag_fcm, pattern = toptag)
textplot_network(topgat_fcm, min_freq = 50, edge_alpha = 0.8, edge_size = 1)
user_dfm <- dfm_select(tweet_dfm, pattern = "@*")
topuser <- names(topfeatures(user_dfm, 50))
head(topuser, 20)
user_fcm <- fcm(user_dfm)
head(user_fcm, 20)

user_fcm <- fcm_select(user_fcm, pattern = topuser)
textplot_network(user_fcm, min_freq = 20, edge_color = "firebrick", edge_alpha = 0.8, edge_size = 1)

# Sentiment analysis
# install.packages("sentimentr")
library(sentimentr)
sentiment_scores <- sentiment(sum_twt)
head(sentiment_scores)

# Sentiment analysis: other lexicons
# install.packages("syuzhet")
library(syuzhet)
syuzhet_vector <- get_sentiment(sum_twt, method = "syuzhet")
head(syuzhet_vector)
bing_vector <- get_sentiment(sum_twt, method = "bing")
head(bing_vector)
afinn_vector <- get_sentiment(sum_twt, method = "afinn")
head(afinn_vector)
nrc_vector <- get_sentiment(sum_twt, method = "nrc")
head(nrc_vector)
# compare the different methods
sentiment_comparison <- data.frame(syuzhet = syuzhet_vector,
                                   bing = bing_vector,
                                   afinn = afinn_vector,
                                   nrc = nrc_vector)
head(sentiment_comparison)

# Plot comparison

library(reshape2)
library(ggplot2)
sentiment_melted <- melt(sentiment_comparison)

ggplot(sentiment_melted, aes(x = variable, y = value, fill = variable)) +
  geom_boxplot() +
  labs(title = "Sentiment Score Comparison Across Methods",
       x = "Sentiment Method",
       y = "Sentiment Score") +
  theme_bw()

# Aggregate sentiment by tweet
agg_sentiment <- aggregate(sentiment_scores$sentiment, by = list(sentiment_scores$
element_id), FUN = mean)
colnames(agg_sentiment) <- c("tweet_id", "avg_sentiment")
head(agg_sentiment)
