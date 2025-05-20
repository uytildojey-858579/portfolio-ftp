#!/bin/bash

# Crée le réseau s'il n'existe pas déjà
if ! docker network ls | grep -q intranet; then
  docker network create intranet
fi

# Démarre chaque compose dans l’ordre
(
  cd mysql_docker && docker-compose up -d
)

(
  cd wordpress_docker && docker-compose up -d
)
