#!/usr/bin/bash

[ $# -eq 0 ] && { echo "Usage: $0 <mastodon.vipnunes.com> <vip> <contato@vipnunes.com>"; exit 1; }

# structure
mkdir -p ./data/{web,elasticsearch,postgresql,redis}
mkdir -p ./data/web/{assets,system}
chown -R 991:991 ./data/web

DOC="$( which docker-compose )"

DOMAIN="$1"
MASTODON_ADMIN_USERNAME="$2"
MASTODON_ADMIN_EMAIL="$3"


$DOC down

echo "[ i ] Preparing instance ${DOMAIN}..."

# Create db.env
touch ./env/db.env
echo "" > ./env/db.env

__PG_HOST="postgresql"
#__PG_ADMIN="mastodon"
__PG_USER="mastodon"
__PG_DB="mastodon_production"

# PostgreSQL
echo "POSTGRES_USER=$__PG_USER" >> ./env/db.env
echo "POSTGRES_DB=$__PG_DB" >> ./env/db.env
# Mastodon DB access
echo "DB_HOST=$__PG_HOST" >> ./env/db.env
echo "DB_USER=$__PG_USER" >> ./env/db.env
echo "DB_NAME=$__PG_DB" >> ./env/db.env
echo "DB_PORT=5432" >> ./env/db.env
# Redis
echo "REDIS_HOST=redis" >> ./env/db.env
echo "REDIS_PORT=6379" >> ./env/db.env
echo "CACHE_REDIS_HOST=redis-cache" >> ./env/db.env
echo "CACHE_REDIS_PORT=6379" >> ./env/db.env
# elasticsearch
echo "ES_JAVA_OPTS='-Xms512m -Xmx512m'" >> ./env/db.env
echo "ES_ENABLED=true" >> ./env/db.env
echo "ES_HOST=elasticsearch" >> ./env/db.env
echo "ES_PORT=9200" >> ./env/db.env
echo "ES_USER=elastic" >> ./env/db.env

# generate passwords
__PWD_PG=$( openssl rand -hex 16 )
__PWD_ES=$( openssl rand -hex 16 )

echo "POSTGRES_PASSWORD=${__PWD_PG}" >> ./env/db.env
echo "DB_PASS=${__PWD_PG}" >> ./env/db.env
echo "ELASTIC_PASSWORD=${__PWD_ES}" >> ./env/db.env
echo "ES_PASS=${__PWD_ES}" >> ./env/db.env

[ ! -s ./env/db.env ] && { echo "[ ! ] Failed to create database environment file."; exit 1; }
echo "[ i ] Database environment file created."

# secure the file
chmod 0600 ./env/db.env

# Create app.env
touch ./env/app.env
echo "" > ./env/app.env

echo "S3_ENABLED=false" >> ./env/app.env
echo "RAILS_ENV=production" >> ./env/app.env
echo "NODE_ENV=production" >> ./env/app.env
echo "LOCAL_DOMAIN=${1}" >> ./env/app.env
echo "SINGLE_USER_MODE=false" >> ./env/app.env

# do not serve static files via rails
echo "RAILS_SERVE_STATIC_FILES=false" >> ./env/app.env
# instance locale - CZ
echo "DEFAULT_LOCALE=cs" >> ./env/app.env

__S_KEY=$( openssl rand -hex 64 )
__S_OTP=$( openssl rand -hex 64 )

rm -rf ./tmp
mkdir -p ./tmp/
openssl ecparam -name prime256v1 -genkey -noout -out ./tmp/vapid_private_key.pem > /dev/null 2>&1
openssl ec -in ./tmp/vapid_private_key.pem -pubout -out ./tmp/vapid_public_key.pem > /dev/null 2>&1

__S_VAP_PUB=$( cat -e ./tmp/vapid_public_key.pem | sed -e "1 d" -e "$ d" | tr -d "\n" )
__S_VAP_PRI=$( cat -e ./tmp/vapid_private_key.pem | sed -e "1 d" -e "$ d" | tr -d "\n" )

rm -rf ./tmp

# Set the application secrets
echo "SECRET_KEY_BASE=${__S_KEY}" >> ./env/app.env
echo "OTP_SECRET=${__S_OTP}" >> ./env/app.env
echo "VAPID_PRIVATE_KEY=${__S_VAP_PRI}" >> ./env/app.env
echo "VAPID_PUBLIC_KEY=${__S_VAP_PUB}" >> ./env/app.env

[ ! -s ./env/app.env ] && { echo "[ ! ] Failed to create application environment file."; exit 1; }
echo "[ i ] Application environment file created."

# Secure the file
chmod 0600 ./env/app.env

# Copy static files
echo "[ i ] Copying static files..."
$DOC run --rm -u root control bash -c "cp -r /mastodon/public/* /web/"

# Prepare PostgreSQL database
$DOC up -d postgresql redis redis-cache elasticsearch
echo "[ i ] Waiting for database..."
sleep 20

CHECK=./data/.provisioned

if [ -f "$CHECK" ]; then
	echo "Provisioning not required"
else

	$DOC run --rm control bundle exec rake db:migrate

	$DOC run --rm control bin/tootctl search deploy
	$DOC run --rm control bin/tootctl accounts create $MASTODON_ADMIN_USERNAME --email $MASTODON_ADMIN_EMAIL --confirmed --role Owner

	echo "[ i ] Provisioning done"
	touch "$CHECK"
fi

$DOC up -d

