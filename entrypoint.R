#!/usr/local/bin/Rscript

dht::greeting()

dht::check_ram(4)

## load libraries without messages or warnings
withr::with_message_sink("/dev/null", library(dplyr))
withr::with_message_sink("/dev/null", library(tidyr))
withr::with_message_sink("/dev/null", library(purrr))
withr::with_message_sink("/dev/null", library(sf))

doc <- "
      Usage:
      entrypoint.R <filename> [<buffer_radius>]
      "

opt <- docopt::docopt(doc)

## for interactive testing
## opt <- docopt::docopt(doc, args = c('test/my_address_file_geocoded.csv', 400))
## roads1100 <- readRDS("roads1100_sf_5072.rds")
## roads1200 <- readRDS("roads1200_sf_5072.rds")

if (is.null(opt$buffer_radius)) {
  opt$buffer_radius <- 400
}

message("reading input file...")
d <- dht::read_lat_lon_csv(opt$filename, nest_df = T, sf = T, project_to_crs = 5072)

dht::check_for_column(d$raw_data, "lat", d$raw_data$lat)
dht::check_for_column(d$raw_data, "lon", d$raw_data$lon)

d_sf <- d$d

message("reading in S1100 roads data...")
roads1100 <- readRDS("/app/roads1100_sf_5072.rds")
message("reading in S1200 roads data...")
roads1200 <- readRDS("/app/roads1200_sf_5072.rds")

message('finding distance to nearest S1100 road...')
nearest_index_1100 <- st_nearest_feature(d_sf, roads1100)
d_sf$dist_to_1100 <- purrr::map2_dbl(1:nrow(d_sf),
                                     nearest_index_1100,
                                     ~sf::st_distance(d_sf[.x,], roads1100[.y,]))

message('finding distance to nearest S1200 road...')
nearest_index_1200 <- st_nearest_feature(d_sf, roads1200)
d_sf$dist_to_1200 <- purrr::map2_dbl(1:nrow(d_sf),
                                     nearest_index_1200,
                                     ~sf::st_distance(d_sf[.x,], roads1200[.y,]))

message("creating buffers...")
buffers <- st_buffer(d_sf, dist = as.numeric(opt$buffer_radius), nQuadSegs = 1000)

get_line_length <- function(roads) {
  # find index of roads that intersect; if none, make length 0
  b <- buffers %>%
    mutate(buffer_index = 1:nrow(.),
           road_index = st_intersects(buffers, roads, sparse = TRUE),
           l = map_dbl(road_index, length),
           road_length = ifelse(l > 0, 1, 0))

  # split into 2 dataframe based on length 0 or not
  b_split <- split(b, b$road_length)

  # for buffers with any length, find that length
  if(length(b_split) > 1) {
    roads_intersects <- purrr::map(b_split$`1`$road_index, ~roads[.x,])
    roads_intersection <- purrr::map2(1:nrow(b_split$`1`),
                                      roads_intersects,
                                      ~st_intersection(b_split$`1`[.x,], .y))
    roads_intersection <- purrr::map(roads_intersection, st_union)
    b_split$`1`$road_length <- round(purrr::map_dbl(roads_intersection, st_length))
  }

  b <- bind_rows(b_split) %>%
    arrange(buffer_index)

  return(b$road_length)
}

message("finding length of S1100 roads within buffer...")
d_sf$length_1100 <- suppressWarnings(get_line_length(roads = roads1100))
message("finding length of S1200 roads within buffer...")
d_sf$length_1200 <- suppressWarnings(get_line_length(roads = roads1200))

## merge back on .row after unnesting .rows into .row
dht::write_geomarker_file(d = d_sf,
                          raw_data = d$raw_data,
                          filename = opt$filename,
                          argument = glue::glue("{opt$buffer_radius}m_buffer"))


