#!/bin/bash
echo ECS_CLUSTER="${ecs_cluster}" >> /etc/ecs/ecs.config
echo ECS_ENGINE_AUTH_TYPE=dockercfg >> /etc/ecs/ecs.config
cat <<EOF >> /etc/ecs/ecs.config
ECS_ENGINE_AUTH_DATA={"https://index.docker.io/v1/":{"auth":"${dockerhub_auth}","email":"${dockerhub_email}"}}
EOF
