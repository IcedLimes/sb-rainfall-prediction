# Helpers that turn the raw NOAA daily summaries into model-ready data.
# Sourced by analysis/rainfall_prediction.Rmd and covered by tests/testthat.

# GHCN-Daily stores precipitation, temperature and wind in tenths of a unit
# (see data/README.md); humidity is already in percent.
read_station_data <- function(path) {
  raw <- utils::read.csv(path, stringsAsFactors = FALSE)
  names(raw) <- tolower(names(raw))
  tibble::tibble(
    date    = as.Date(raw$date),
    prcp_mm = raw$prcp / 10,
    tmax_c  = raw$tmax / 10,
    tmin_c  = raw$tmin / 10,
    awnd_ms = raw$awnd / 10,
    rhmn    = raw$rhmn,
    rhmx    = raw$rhmx
  )
}

# Drops days with a missing measurement, plus a few days that record an
# impossible 100% minimum and 0% maximum relative humidity.
clean_station_data <- function(daily) {
  daily <- daily[stats::complete.cases(daily), ]
  daily[daily$rhmn <= daily$rhmx, ]
}

# Water years run October-September, so each one holds exactly one rainy season.
water_year <- function(date) {
  as.integer(format(date, "%Y")) + (as.integer(format(date, "%m")) >= 10)
}

# One row per day: that day's weather as predictors and whether it rains
# `horizon` days later as the outcome. Outcomes are matched by calendar date,
# so a gap in the record never pairs a day with the wrong "tomorrow".
#
# horizon = 0 gives the same-day version of the problem, where the day's own
# rainfall is the outcome and so cannot also be a predictor.
build_model_data <- function(daily, horizon = 1L) {
  features <- clean_station_data(daily)
  day_of_year <- as.integer(format(features$date, "%j"))
  features$doy_sin <- sin(2 * pi * day_of_year / 365.25)
  features$doy_cos <- cos(2 * pi * day_of_year / 365.25)

  if (horizon == 0) {
    features$prcp_mm <- NULL
  } else {
    features$rain_today <- as.integer(features$prcp_mm > 0)
    features$prcp_log <- log1p(features$prcp_mm)
    features$prcp_mm <- NULL
  }

  observed <- daily[!is.na(daily$prcp_mm), ]
  outcome <- tibble::tibble(
    date       = observed$date - horizon,
    water_year = water_year(observed$date),
    rain       = factor(ifelse(observed$prcp_mm > 0, "yes", "no"), levels = c("yes", "no"))
  )

  dplyr::inner_join(features, outcome, by = "date")
}

# Chronological split: the last `test_years` complete rainy seasons are held out.
split_by_water_year <- function(model_data, test_years = 4L) {
  first_test_year <- max(model_data$water_year) - test_years + 1L
  list(
    train = model_data[model_data$water_year < first_test_year, ],
    test  = model_data[model_data$water_year >= first_test_year, ]
  )
}
