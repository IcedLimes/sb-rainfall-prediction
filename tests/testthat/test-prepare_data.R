source(here::here("R", "prepare_data.R"))

# A small daily record with a gap on Jan 4 and a bad humidity reading on Jan 6.
toy_daily <- function() {
  tibble::tibble(
    date    = as.Date(c("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-05", "2020-01-06", "2020-01-07")),
    prcp_mm = c(0, 5, 0, 1.3, 0, 0),
    tmax_c  = c(18, 15, 17, 16, 20, 21),
    tmin_c  = c(8, 9, 7, 10, 11, 9),
    awnd_ms = c(2.1, 5.4, 3, 4, NA, 2),
    rhmn    = c(40, 80, 50, 70, 100, 30),
    rhmx    = c(90, 100, 95, 100, 0, 85)
  )
}

test_that("raw values are converted from tenths to real units", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(
    "STATION,DATE,PRCP,TMAX,TMIN,AWND,RHAV,RHMN,RHMX",
    "USW00023190,2006-01-01,323,144,-44,43,89,78,97"
  ), path)

  daily <- read_station_data(path)

  expect_equal(daily$date, as.Date("2006-01-01"))
  expect_equal(daily$prcp_mm, 32.3)
  expect_equal(daily$tmax_c, 14.4)
  expect_equal(daily$tmin_c, -4.4)
  expect_equal(daily$awnd_ms, 4.3)
  expect_equal(c(daily$rhmn, daily$rhmx), c(78, 97))
})

test_that("cleaning drops missing values and impossible humidity", {
  cleaned <- clean_station_data(toy_daily())
  expect_equal(cleaned$date, as.Date(c("2020-01-01", "2020-01-02", "2020-01-03", "2020-01-05", "2020-01-07")))

  bad_rh <- toy_daily()
  bad_rh$awnd_ms[5] <- 3
  expect_false(as.Date("2020-01-06") %in% clean_station_data(bad_rh)$date)
})

test_that("next-day outcome is tomorrow's rain, matched by date", {
  model_data <- build_model_data(toy_daily(), horizon = 1)
  rain_on <- function(d) as.character(model_data$rain[model_data$date == as.Date(d)])

  expect_equal(rain_on("2020-01-01"), "yes")  # Jan 2 had 5 mm
  expect_equal(rain_on("2020-01-02"), "no")   # Jan 3 was dry
  # Jan 4 is missing, so Jan 3 has no "tomorrow" and must not borrow Jan 5.
  expect_false(as.Date("2020-01-03") %in% model_data$date)
  # Jan 7 is the last day on record, so it has no outcome either.
  expect_false(as.Date("2020-01-07") %in% model_data$date)
})

test_that("a day with bad sensor data still counts as someone's tomorrow", {
  # Jan 6 is dropped as a predictor row, but its rainfall is valid.
  model_data <- build_model_data(toy_daily(), horizon = 1)
  expect_equal(as.character(model_data$rain[model_data$date == as.Date("2020-01-05")]), "no")
})

test_that("next-day predictors describe today only", {
  daily <- toy_daily()
  model_data <- build_model_data(daily, horizon = 1)
  jan2 <- model_data[model_data$date == as.Date("2020-01-02"), ]

  expect_equal(jan2$tmax_c, 15)
  expect_equal(jan2$rain_today, 1L)
  expect_equal(jan2$prcp_log, log1p(5))

  # Changing tomorrow's weather must not change today's predictors.
  daily$tmax_c[3] <- 99
  daily$rhmn[3] <- 1
  changed <- build_model_data(daily, horizon = 1)
  predictors <- setdiff(names(model_data), c("rain", "water_year"))
  expect_equal(changed[changed$date == as.Date("2020-01-02"), predictors], jan2[, predictors])
})

test_that("same-day data never uses the day's own rainfall as a predictor", {
  model_data <- build_model_data(toy_daily(), horizon = 0)
  expect_false(any(c("prcp_mm", "prcp_log", "rain_today") %in% names(model_data)))
  expect_equal(as.character(model_data$rain[model_data$date == as.Date("2020-01-02")]), "yes")
})

test_that("both outcome levels are always present with 'yes' as the event", {
  all_dry <- toy_daily()
  all_dry$prcp_mm <- 0
  expect_equal(levels(build_model_data(all_dry)$rain), c("yes", "no"))
})

test_that("water years start on October 1", {
  expect_equal(water_year(as.Date(c("2020-09-30", "2020-10-01", "2021-01-15"))), c(2020L, 2021L, 2021L))
})

test_that("the train/test split is chronological and complete", {
  daily <- read_station_data(here::here("data", "santa_barbara_airport_daily.csv"))
  model_data <- build_model_data(daily)
  split <- split_by_water_year(model_data, test_years = 4)

  expect_equal(nrow(split$train) + nrow(split$test), nrow(model_data))
  expect_lt(max(split$train$date), min(split$test$date))
  expect_equal(sort(unique(split$test$water_year)), 2021:2024)
})

test_that("the bundled dataset matches what the analysis assumes", {
  raw <- utils::read.csv(here::here("data", "santa_barbara_airport_daily.csv"))
  expect_setequal(names(raw), c("STATION", "DATE", "LATITUDE", "LONGITUDE", "ELEVATION", "NAME",
                                "PRCP", "TMAX", "TMIN", "AWND", "RHAV", "RHMN", "RHMX"))
  expect_equal(unique(raw$STATION), "USW00023190")
  dates <- as.Date(raw$DATE)
  expect_false(anyDuplicated(dates) > 0)
  expect_false(is.unsorted(dates))
  expect_false(anyNA(raw$PRCP))
})
