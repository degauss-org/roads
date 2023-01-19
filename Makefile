.PHONY: build test shell clean

build:
	docker build -t roads .

test:
	docker run --rm -v "${PWD}/test":/tmp roads my_address_file_geocoded.csv
	docker run --rm -v "${PWD}/test":/tmp roads my_address_file_geocoded.csv 1000
	docker run --rm -v "${PWD}/test":/tmp roads my_address_file_geocoded_shorter.csv 1000

shell:
	docker run --rm -it --entrypoint=/bin/bash -v "${PWD}/test":/tmp roads

clean:
	docker system prune -f
