library(terra)

in_dir  <- "F:/ndvi/era52"
out_dir <- "F:/ndvi/era54"

dir.create(out_dir, showWarnings = FALSE)

files <- list.files(in_dir, pattern="\\.grib$", full.names=TRUE)

target_res <- 0.01  # degrees (~1 km, depends on latitude!)

for (f in files) {
  
  r <- rast(f)
  
  if (nlyr(r) > 1) r <- r[[2]]
  
  r_template <- rast(ext(r), resolution = target_res, crs = crs(r))
  
  r_fine <- resample(r, r_template, method = "bilinear")
  
  name <- tools::file_path_sans_ext(basename(f))
  
  writeRaster(
    r_fine,
    file.path(out_dir, paste0(name, "_1km.tif")),
    overwrite=TRUE
  )
  
}
