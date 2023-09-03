#!/usr/bin/bash

DOC="$( which docker-compose )"

$DOC up -d
sleep 5
$DOC up -d nginx-proxy