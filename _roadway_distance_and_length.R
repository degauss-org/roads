#!/usr/local/bin/Rscript

suppressPackageStartupMessages(library(argparser))
p <- arg_parser('return distance to nearest and length of S1100 and S1200 roadways within buffer')
p <- add_argument(p, 'file_name', help = 'name of geocoded csv file')
p <- add_argument(p, '--buffer_radius', default = 400, help = 'optional; defaults to 300 m')
args <- parse_args(p)

suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(sp))
suppressPackageStartupMessages(library(rgeos))
suppressPackageStartupMessages(library(rgdal))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(purrr))
suppressPackageStartupMessages(library(tidyr))

message('\nloading and projecting S1100 roads shapefile...')
# roads1100 <- tigris::primary_roads(year=2018) %>%
#   spTransform(CRS('+init=epsg:5072'))
# saveRDS(roads1100, "roads1100_sp_5072.rds")
roads1100 <- readRDS("/app/roads1100_sp_5072.rds")

message('\nloading and projecting S1200 roads shapefile...')
# roads1200 <- rgdal::readOGR(dsn="all_TIGER_roads_2018.gpkg") %>%
#   spTransform(CRS('+init=epsg:5072'))
# saveRDS(roads1200, "roads1200_sp_5072.rds")
roads1200 <- readRDS("/app/roads1200_sp_5072.rds")

message('\nloading and projecting input file...')
raw_data <- suppressMessages(read_csv(args$file_name))
## raw_data <- suppressMessages(read_csv('./tests/my_address_file_geocoded.csv'))

raw_data$.row <- seq_len(nrow(raw_data))

d <-
  raw_data %>%
  select(.row, lat, lon) %>%
  na.omit() %>%
  group_by(lat, lon) %>%
  nest(.rows = c(.row))

coordinates(d) <- c('lon','lat')
proj4string(d) <- CRS('+init=epsg:4326')
d <- spTransform(d, CRS('+init=epsg:5072'))

message('\nfinding distance to nearest S1100 road...')
d@data$dist_to_1100 <- rgeos::gDistance(d,roads1100,byid=c(TRUE,FALSE)) %>% as.vector

message('\nfinding distance to nearest S1200 road...')
d@data$dist_to_1200 <- rgeos::gDistance(d,roads1200,byid=c(TRUE,FALSE)) %>% as.vector

d <- st_as_sf(d) %>% st_set_crs(5072)
roads1100 <- st_as_sf(roads1100) %>% st_set_crs(5072)
roads1200 <- st_as_sf(roads1200) %>% st_set_crs(5072)

get_line_length <- function(locations,lines.shapefile,buffer.radius=args$buffer_radius) {
  locations <- locations %>%
    mutate(index = 1:nrow(.)) %>%
    dplyr::group_by(index) %>%
    tidyr::nest()
  buffer <- purrr::map(locations$data, ~sf::st_buffer(.x, dist=buffer.radius, nQuadSegs=1000))
  suppressWarnings(crop.buffer <- purrr::map(buffer, ~sf::st_intersection(.x, lines.shapefile))) # slow (slower for S1200)
  lengths <- list()
  crop.buffer.overlap <- list()
  for (i in 1:length(crop.buffer)) {
    if (purrr::is_empty(crop.buffer[[i]]$geometry)) {
      lengths[[i]] <- 0
    } else {
      crop.buffer.overlap[[i]] <- sf::st_intersection(crop.buffer[[i]])
      lengths[[i]] <- sf::st_length(crop.buffer.overlap[[i]])
    }
  }
  unique.lengths <- purrr::map(lengths, ~unique(.x))
  length.total <- purrr::map_dbl(unique.lengths, ~sum(.x))
  return(length.total)
}

message('\nfinding length of S1100 roads within buffer...')
d$length_1100 <- get_line_length(locations = d, lines.shapefile = roads1100)

message('\nfinding length of S1200 roads within buffer...')
d$length_1200 <- get_line_length(locations = d, lines.shapefile = roads1200)

## merge back on .row after unnesting data into .row
d <- d %>%
  unnest(cols = c(.rows))%>%
  st_drop_geometry()

out_file <- left_join(raw_data, d, by = '.row') %>% select(-.row)

out_file_name <- paste0(tools::file_path_sans_ext(args$file_name), '_roads_', args$buffer_radius, 'm_buffer.csv')

write_csv(out_file, out_file_name)

message('\nFINISHED! output written to ', out_file_name)








