# download
wget -r ftp://ftp2.census.gov/geo/tiger/TIGER2018/ROADS/*

# unzip files
mkdir ./all_2018_roads
find ftp2.census.gov -type f -name "*.zip" -print0 | xargs -0 -I{} unzip {} -d ./all_2018_roads


# subset all of the shapefiles to each of the road classes
mkdir ./TIGER2018_S1200_roads

# if ls is aliased to `ls --color` than ansi color strings will be returned, preventing the grep from working!
for f in `\ls all_2018_roads/ | grep .shp$`; do
    ogr2ogr -where "MTFCC = 'S1200'" TIGER2018_S1200_roads/$f all_2018_roads/$f
done

# merge all of these together
# utility taken from the python-gdal package
ogrmerge.py -o all_TIGER_roads_2018.gpkg TIGER2018_S1200_roads/*.shp -progress -f GPKG -single

# cleanup
rm -r ftp2.census.gov
rm -r all_2018_roads
rm -r TIGER2018_S1200_roads

