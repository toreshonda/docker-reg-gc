#!/bin/bash

LIVINGDAYS=${1-150}
DOCKER_REGISTRY="https://yourDockerRegUrl.de/v2"
ACCEPT_HEADER="Accept: application/vnd.docker.distribution.manifest.v2+json"

function get_repositories {
  curl -Ls "${DOCKER_REGISTRY}"/_catalog | jq -r '."repositories"[]'
}

function get_repository_tags {
  REPOSITORY="$1"
  curl -Ls "${DOCKER_REGISTRY}"/"${REPOSITORY}"/tags/list | jq -r '."tags"[]'
}

function get_tag_created_date_sec {
  REPOSITORY="$1"
  TAG="$2"
  TAGBLOBDIGEST=$(curl -Ls --header "${ACCEPT_HEADER}" GET "${DOCKER_REGISTRY}"/"${REPOSITORY}"/manifests/"${TAG}" | jq -r '.config.digest')
  if [ ! -z "$TAGBLOBDIGEST" ] && [ "$TAGBLOBDIGEST" != "null" ]
  then
      date -d $(curl -Ls GET "${DOCKER_REGISTRY}"/"${REPOSITORY}"/blobs/"${TAGBLOBDIGEST}" | jq '.created' | tail -n1 | grep -o "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]") +%s
  else
      date -d now +%s
  fi
}

function get_tag_digest {
  REPOSITORY="$1"
  TAG="$2"
  curl -ILs --header "${ACCEPT_HEADER}" "${DOCKER_REGISTRY}"/"${REPOSITORY}"/manifests/"${TAG}" | grep Docker-Content-Digest | awk '{print $2}'
}

REPORITORIES=$(get_repositories)
for REPOSITORY in ${REPORITORIES[@]}
do
  TAGS=$(get_repository_tags "${REPOSITORY}")
  if [ "${#TAGS[@]}" -gt 0 ]
  then
      for TAG in ${TAGS[@]}
      do
        TAG_CREATE_DATE_SEC=$(get_tag_created_date_sec "${REPOSITORY}" "${TAG}")
        NOW_SEC=$(date -d now +%s)
        DAYSBETWEEN=$(( (${NOW_SEC} - ${TAG_CREATE_DATE_SEC}) / 86400 ))
        if [ "${DAYSBETWEEN}" -gt "${LIVINGDAYS}" ];
        then
          DIGEST=$(get_tag_digest "${REPOSITORY}" "${TAG}")
          echo DELETE "${DOCKER_REGISTRY}"/"${REPOSITORY}" "${TAG}" it is "${DAYSBETWEEN}" days old
          curl -Ls --header "${ACCEPT_HEADER}" -X DELETE "${DOCKER_REGISTRY%$'\r'}"/"${REPOSITORY%$'\r'}"/manifests/"${DIGEST%$'\r'}"
        fi
      done
  fi
done

#if you want to do the garbage collection which finally cleans up your filesystem in this script just put this script into a cronjob which runs in the night when your registry is not used!
#for that you will need the following 4 lines (to avoid problem restart of docker-registry is required after garbage collection):

#REGISTRY_CONTAINER_ID="docker-registry"
#REGISTRY_CONFIG="/etc/docker/registry/config.yml"
#docker exec -it "${REGISTRY_CONTAINER_ID}" bin/registry garbage-collect "${REGISTRY_CONFIG}"
#docker restart "${REGISTRY_CONTAINER_ID}"
