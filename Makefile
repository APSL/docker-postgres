all: build

TAG=9.5.4
IMAGE=apsl/postgres:$(TAG)

TAG_NOPOSTGIS=9.6.0-nopostgis
IMAGE_NOPOSTGIS=apsl/postgres:$(TAG_NOPOSTGIS)

build:
	docker build -t $(IMAGE) -f Dockerfile .
	docker push $(IMAGE)

build_nopostgis:
	docker build -t $(IMAGE_NOPOSTGIS) -f Dockerfile_9.6_no-postgis .
	docker push $(IMAGE_NOPOSTGIS)

.PHONY: build build_nopostgis
