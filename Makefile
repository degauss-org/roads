.PHONY: build test shell clean

build:
	docker build -t roads .

test:
	docker run --rm -v "${PWD}/test":/tmp roads my_address_file_geocoded.csv

shell:
	docker run --rm -it --entrypoint=/bin/bash -v "${PWD}/test":/tmp roads

clean:
	docker system prune -f