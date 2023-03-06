#!/usr/bin/bash

docker-compose down
rm -rf ./data && mkdir ./data
touch ./data/.placeholder
echo "" > ./env/app.env
echo "" > ./env/db.env
touch ./env/smtp.env
chmod 0600 ./env/smtp.env

