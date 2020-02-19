FROM rocker/r-ver:3.6.1

# install a newer-ish version of renv, but the specific version we want will be restored from the renv lockfile
ENV RENV_VERSION 0.8.3-81
RUN R --quiet -e "source('https://install-github.me/rstudio/renv@${RENV_VERSION}')"

WORKDIR /app

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends \
  libgdal-dev=2.1.2+dfsg-5 \
  libgeos-dev=3.5.1-3 \
  libudunits2-dev=2.2.20-1+b1 \
  libproj-dev=4.9.3-1 \
  && apt-get clean

COPY renv.lock .
RUN R --quiet -e "renv::restore()"

COPY roads1100_sp_5072.rds .
COPY roads1200_sp_5072.rds .
COPY _roadway_distance_and_length.R .

WORKDIR /tmp

ENTRYPOINT ["/app/_roadway_distance_and_length.R"]
