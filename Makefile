.PNOHY: all build upload

all: build upload

build:
	hugo --theme=vienna -v

upload:
	s3_website push
