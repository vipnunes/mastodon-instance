#!/usr/bin/bash

[ $# -eq 0 ] && { echo "Usage: $0 <mastodon version>"; exit 1; }

echo "" > .env
echo "MASTODON_VER=\"$1\"" >> .env

DOC="$( which docker-compose )"

$DOC down
$DOC pull web streaming sidekiq control
$DOC run --rm -u root control bash -c "cp -r /mastodon/public/* /web/"
$DOC up -d postgresql redis redis-cache elasticsearch
sleep 10
$DOC run --rm control bundle exec rake db:migrate
$DOC up -d
