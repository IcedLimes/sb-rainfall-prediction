# Data

`santa_barbara_airport_daily.csv` contains NOAA daily weather summaries (GHCN-Daily) for **Santa Barbara Municipal Airport, CA** (station `USW00023190`), 1 January 2006 to 30 September 2024: 6,847 rows, one per day.

## Source

National Centers for Environmental Information (NCEI), *Global Historical Climatology Network – Daily* ([Menne et al., 2012](https://doi.org/10.1175/JTECH-D-11-00103.1)). The same values can be downloaded again from NCEI's Access Data Service:

```
https://www.ncei.noaa.gov/access/services/data/v1?dataset=daily-summaries&stations=USW00023190&startDate=2006-01-01&endDate=2024-09-30&dataTypes=PRCP,TMAX,TMIN,AWND,RHAV,RHMN,RHMX&includeStationName=true&includeStationLocation=1&format=csv
```

The service returns the columns in a different order, but the values are identical. NOAA data are a U.S. Government work and are in the public domain.

## Columns

| Column | Description | Units in file |
|---|---|---|
| `STATION` | GHCN station ID (constant) | – |
| `DATE` | Observation date | `YYYY-MM-DD` |
| `LATITUDE`, `LONGITUDE` | Station location (constant) | decimal degrees |
| `ELEVATION` | Station elevation (constant) | metres |
| `NAME` | Station name (constant) | – |
| `PRCP` | Precipitation | tenths of a millimetre |
| `TMAX` | Maximum temperature | tenths of a degree Celsius |
| `TMIN` | Minimum temperature | tenths of a degree Celsius |
| `AWND` | Average daily wind speed | tenths of a metre per second |
| `RHAV` | Average relative humidity | percent |
| `RHMN` | Minimum relative humidity | percent |
| `RHMX` | Maximum relative humidity | percent |

`read_station_data()` in [`R/prepare_data.R`](../R/prepare_data.R) converts the tenths into millimetres, °C and m/s.

## Known issues

- **One missing day:** 2022-05-31 has no row. The next-day outcome is matched by date, so this gap drops one forecast instead of shifting all the ones after it.
- **Missing values:** 76 days are missing at least one of the measurements used in the models (mostly humidity). These days are dropped as predictors, but their rainfall still counts as the outcome for the day before.
- **Impossible humidity:** 2006-05-22, 2006-05-23 and 2007-12-09 record 100% minimum and 0% maximum humidity. `clean_station_data()` drops them.
- **Trace precipitation** is recorded as 0, so a "rain day" means at least 0.3 mm (0.01 in) was measured.
