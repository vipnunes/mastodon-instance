#!/usr/bin/bash

DOC="$( which docker-compose )"

$DOC down
$DOC pull web streaming sidekiq control
$DOC run --rm -u root control bash -c "cp -r /mastodon/public/* /web/"
$DOC up -d postgresql redis redis-cache
sleep 10
$DOC run --rm control bundle exec rake db:migrate
$DOC up -d
