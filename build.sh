#!/bin/bash -e

docker build -t zardus/research:cyborg .
docker push zardus/research:cyborg
