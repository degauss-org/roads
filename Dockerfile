FROM rocker/r-ver:4.0.5

# DeGAUSS container metadata
ENV degauss_name="roads"
ENV degauss_version="0.2.3"
ENV degauss_description="proximity and length of major roads"
ENV degauss_argument="buffer radius in meters [default: 400]"

# add OCI labels based on environment variables too
LABEL "org.degauss.name"="${degauss_name}"
LABEL "org.degauss.version"="${degauss_version}"
LABEL "org.degauss.description"="${degauss_description}"
LABEL "org.degauss.argument"="${degauss_argument}"

RUN R --quiet -e "install.packages('remotes', repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

RUN R --quiet -e "remotes::install_github('rstudio/renv@0.15.2')"

WORKDIR /app

RUN apt-get update \
    && apt-get install -yqq --no-install-recommends \
    libgdal-dev \
    libgeos-dev \
    libudunits2-dev \
    libproj-dev \
    && apt-get clean

COPY renv.lock .

RUN R --quiet -e "renv::restore(repos = c(CRAN = 'https://packagemanager.rstudio.com/all/__linux__/focal/latest'))"

ADD https://github.com/degauss-org/roads/releases/download/0.2.2/roads1100_sf_5072.rds roads1100_sf_5072.rds
ADD https://github.com/degauss-org/roads/releases/download/0.2.2/roads1200_sf_5072.rds roads1200_sf_5072.rds
COPY entrypoint.R .

WORKDIR /tmp

ENTRYPOINT ["/app/entrypoint.R"]
