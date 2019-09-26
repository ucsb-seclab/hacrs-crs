#!/bin/bash -e

#
# stop old processes
#

( docker stop -t 10 cyborg-db && docker rm cyborg-db ) || echo "[-] No DB running."
( docker stop -t 10 cyborg-meister && docker rm cyborg-meister ) || echo "[-] No Meister running."

#
# generate settings and make the env file
#

DOCKER_HOST=$(ip a show dev docker0 | grep " inet " | awk '{print $6}' FS="/? ?")
PGHOST=${PGADDRESS-$DOCKER_HOST}
PGPASSWORD=password$RANDOM
cat <<END > env
KUBERNETES_SERVICE_HOST=
KUBERNETES_SERVICE_PORT=8080
KUBERNETES_SERVICE_TOKEN=xxx
KUBERNETES_SERVICE_USER=admin

#CGC_API_USER=team-6
#CGC_API_PASS=xxx
#CGC_API_SERVICE_HOST=172.16.7.73
#CGC_API_SERVICE_PORT=8888

MEISTER_LOG_LEVEL=INFO
WORKER_IMAGE=worker
WORKER_IMAGE_PULL_POLICY=Always
MEISTER_PRIORITY_STAGGERING=100
MEISTER_PRIORITY_STAGGER_FACTOR=1.0

PGPASSWORD=$PGPASSWORD
POSTGRES_DATABASE_NAME=farnsworth
POSTGRES_DATABASE_USER=postgres
POSTGRES_DATABASE_PASSWORD=$PGPASSWORD
POSTGRES_MASTER_SERVICE_HOST=$PGHOST
POSTGRES_MASTER_SERVICE_PORT=5432
END

#
# spin up postgres and set up the DB
#

docker run -e POSTGRES_PASSWORD=$PGPASSWORD -d -p 5432:5432 --name cyborg-db postgres
while ! docker logs cyborg-db 2>&1| grep "ready"
do
	echo Waiting for postgres...
	sleep 5
done
docker run --env-file env --rm zardus/research:cyborg angr-dev/farnsworth/setupdb.sh create

#
# Start up the meister
#
docker run --env-file env --name cyborg-meister -d zardus/research:cyborg -c meister
