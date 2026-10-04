## EPPS 6302 Methods of Data Collection and Production
## Google Trends with R

install.packages("gtrendsR")
library(gtrendsR)
TrumpHarrisElection = gtrends(c("Trump","Harris","election"), onlyInterest = TRUE, geo = "US", gprop = "web", time = "today+5-y", category = 0, ) # last five years
the_df=TrumpHarrisElection$interest_over_time
plot(TrumpHarrisElection)
tg = gtrends("tariff", time = "all")

# Example: Tariff, China military, Taiwan 
# 
plot(gtrends(c("tariff"), time = "all"))
data("countries")
plot(gtrends(c("tariff"), geo = "GB", time = "all")) 
plot(gtrends(c("tariff"), geo = c("US","GB","TW"), time = "all")) 
tg_iot = tg$interest_over_time
tct = gtrends(c("tariff","China military", "Taiwan"), time = "all")
tct = data.frame(tct$interest_over_time)
plot(gtrends(c("tariff","China military", "Taiwan"), time = "all"))


