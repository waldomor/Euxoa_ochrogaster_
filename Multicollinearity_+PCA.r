library(terra)
library(sf)
library(dplyr)
library(readr)
library(stringr)
library(car)
library(stats)
 
CSV_PATH <- "F:/ndvi/occurrences.csv"
ERA5_DIR <- "F:/ndvi/era5/"
NDVI_DIR <- "F:/ndvi/ndvi/"
RASTER_DIR <- "F:/ndvi/rasters/"
EOO_PATH <- "F:/ndvi/eoo.shp"

YEARS <- c(2021, 2022, 2023, 2024, 2025)
ALLOWED_LC <- 40
 
eoo <- st_read(EOO_PATH) |> st_transform(4326)
eoo_geom <- st_union(eoo)

in_eoo <- function(lat, lon) {
  st_within(
    st_sfc(st_point(c(lon, lat)), crs = 4326),
    eoo_geom,
    sparse = FALSE
  )[1,1]
}
 
df <- read_csv(CSV_PATH) |>
  mutate(label = 1)

df <- df |>
  rowwise() |>
  filter(in_eoo(latitude, longitude)) |>
  ungroup()
 
soil_r <- rast(file.path(RASTER_DIR, "soil_texture.tif"))
lc_r   <- rast(file.path(RASTER_DIR, "landcover.tif"))

sample_raster <- function(r, lat, lon) {
  val <- terra::extract(r, cbind(lon, lat))
  as.numeric(val[1,2])
}

soil_suitability <- function(x, opt = 3, sigma = 1) {
  exp(-((x - opt)^2) / (2 * sigma^2))
}

lc_binary <- function(lat, lon) {
  as.numeric(sample_raster(lc_r, lat, lon) == ALLOWED_LC)
}
 
era5_data <- list()

files <- list.files(ERA5_DIR, pattern = "\\.grib$", full.names = TRUE)

for (f in files) {

  year <- str_match(basename(f), "\\d+\\.(\\d{4})\\.grib")[,2]
  if (is.na(year)) next
  year <- as.integer(year)

  r <- try(rast(f), silent = TRUE)
  if (inherits(r, "try-error")) next

  if (!("stl1" %in% names(r)) | !("swvl1" %in% names(r))) next

  era5_data[[as.character(year)]]$temp  <-
    c(era5_data[[as.character(year)]]$temp, list(r[["stl1"]]))

  era5_data[[as.character(year)]]$moist <-
    c(era5_data[[as.character(year)]]$moist, list(r[["swvl1"]]))
}

# yearly mean
era5_mean <- list()

for (y in names(era5_data)) {
  era5_mean[[y]] <- list(
    temp  = Reduce(`+`, era5_data[[y]]$temp) / length(era5_data[[y]]$temp),
    moist = Reduce(`+`, era5_data[[y]]$moist) / length(era5_data[[y]]$moist)
  )
}

sample_era5 <- function(year, lat, lon, var) {
  y <- as.character(year)
  if (!(y %in% names(era5_mean))) return(NA)

  r <- era5_mean[[y]][[var]]
  val <- terra::extract(r, cbind(lon, lat))
  as.numeric(val[1,2])
}
 
ndvi_yearly <- list()

load_ndvi <- function(file) {
  r <- rast(file)
  ndvi <- r[["NDVI"]]

  if ("QA" %in% names(r)) {
    qa <- r[["QA"]]
    ndvi[qa != 0] <- NA
  }

  global(ndvi, "mean", na.rm = TRUE)[1,1]
}

ndvi_files <- list.files(NDVI_DIR, pattern = "\\.nc$", full.names = TRUE)

for (f in ndvi_files) {

  year <- str_match(f, "\\.(\\d{4})")[,2]
  if (is.na(year)) next
  year <- as.integer(year)

  ndvi_yearly[[as.character(year)]] <-
    c(ndvi_yearly[[as.character(year)]], load_ndvi(f))
}

ndvi_yearly <- lapply(ndvi_yearly, mean, na.rm = TRUE)

sample_ndvi <- function(year) {
  ndvi_yearly[[as.character(year)]] %||% NA
}
 
range_suit <- function(x, xmin, xmax) {
  if (is.na(x)) return(NA)
  if (x < xmin) return((x - xmin) / (xmax - xmin))
  if (x > xmax) return((xmax - x) / (xmax - xmin))
  1
}

boyle_index <- function(temp, moist,
                        temp_opt = c(280, 290),
                        moist_opt = c(0.3, 0.5)) {
  mean(c(
    range_suit(temp, temp_opt[1], temp_opt[2]),
    range_suit(moist, moist_opt[1], moist_opt[2])
  ), na.rm = TRUE)
}
 
records <- list()

for (i in 1:nrow(df)) {

  lat <- df$latitude[i]
  lon <- df$longitude[i]

  for (year in YEARS) {

    st  <- sample_era5(year, lat, lon, "temp")
    sm  <- sample_era5(year, lat, lon, "moist")
    nv  <- sample_ndvi(year)
    soil <- sample_raster(soil_r, lat, lon)
    lc   <- lc_binary(lat, lon)
    boy  <- boyle_index(st, sm)

    records[[length(records) + 1]] <- data.frame(
      year = year,
      latitude = lat,
      longitude = lon,
      stl1 = st,
      swvl1 = sm,
      ndvi = nv,
      soil = soil,
      lc = lc,
      boyle = boy,
      label = df$label[i]
    )
  }
}

data <- bind_rows(records)
 
numeric_cols <- c("stl1","swvl1","ndvi","soil","lc","boyle")

data[numeric_cols] <- lapply(data[numeric_cols], function(x) {
  x[is.infinite(x)] <- NA
  x
})

for (col in numeric_cols) {
  data[[col]][is.na(data[[col]])] <- mean(data[[col]], na.rm = TRUE)
}
 
scaled <- scale(data[, numeric_cols])

vif_table <- data.frame(
  feature = numeric_cols,
  VIF = sapply(1:length(numeric_cols), function(i) {
    car::vif(lm(scaled[,1] ~ ., data = as.data.frame(scaled)))[i]
  })
)

write.csv(vif_table, "F:/ndvi/vif_tablekk2.csv", row.names = FALSE)

corr_matrix <- cor(data[, numeric_cols], use = "complete.obs")
write.csv(corr_matrix, "F:/ndvi/correlation_matrixkk2.csv")
 
r2_records <- list()

for (col in numeric_cols) {

  X <- data.frame(x = data[[col]])
  y <- data$label

  model <- lm(y ~ x, data = X)

  r2_records[[col]] <- summary(model)$r.squared
}

r2_table <- data.frame(
  variable = names(r2_records),
  R2_label = unlist(r2_records)
)

write.csv(r2_table, "F:/ndvi/r2_per_variablekk2.csv", row.names = FALSE)


write.csv(data, "F:/ndvi/full_dataset_cleanedkk2.csv", row.names = FALSE)

cat("Data, VIF, correlation, and R² tables saved.\n")
