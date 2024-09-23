#!/usr/bin/env bash
# builds the OLM catalog index and pushes it to quay.io.
#
# To push to your own registry, override the IMG_REGISTRY_HOST , IMG_REGISTRY_ORG , OPERATOR_NAME and TAG env vars,
# i.e:
#   IMG_REGISTRY_HOST=quay.io IMG_REGISTRY_ORG=yourusername OPERATOR_NAME=authorino-operator TAG=latest ./script/build_catalog.sh
#
# REQUIREMENTS:
#  * a valid login session to a container registry.
#  * `docker`
#  * `opm`
#  * `skopeo`
#

#Iterate over tag list i.e. latest 8a17c81d5e9f04545753e5501dddc4a0ac2c7e03
IFS=' ' read -r -a tags <<< "$TAG"

for tag in "${tags[@]}"
do 

  #Fetch Digest for each architecture from the bundle 
  AMD64_DIGEST=$(skopeo inspect --raw  docker://${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${tag} | \
               jq -r '.manifests[] | select(.platform.architecture == "amd64" and .platform.os == "linux").digest')
  POWER_DIGEST=$(skopeo inspect --raw  docker://${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${tag} | \
               jq -r '.manifests[] | select(.platform.architecture == "ppc64le" and .platform.os == "linux").digest')
  Z_DIGEST=$(skopeo inspect --raw  docker://${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${tag} | \
           jq -r '.manifests[] | select(.platform.architecture == "s390x" and .platform.os == "linux").digest')
  ARM64_DIGEST=$(skopeo inspect --raw  docker://${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:${tag} | \
               jq -r '.manifests[] | select(.platform.architecture == "arm64" and .platform.os == "linux").digest')

  #build & push catalog image to container registry
  opm index add --build-tool docker  --tag  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-amd64" --bundles "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:@${AMD64_DIGEST}" --binary-image "quay.io/operator-framework/opm:v1.28.0-amd64"
  docker push ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-amd64

  opm index add --build-tool docker  --tag  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-ppc64le" --bundles "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:@${POWER_DIGEST}" --binary-image "quay.io/operator-framework/opm:v1.28.0-ppc64le"
  docker push ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-ppc64le

  opm index add --build-tool docker  --tag  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-arm64" --bundles "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:@${ARM64_DIGEST}" --binary-image "quay.io/operator-framework/opm:v1.28.0-arm64"
  docker push ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-arm64

  opm index add --build-tool docker  --tag  "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-s390x" --bundles "${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-bundle:@${Z_DIGEST}" --binary-image "quay.io/operator-framework/opm:v1.28.0-s390x"
  docker push ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-s390x


  docker manifest create --amend ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag} \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-amd64 \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-arm64  \
                 ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-ppc64le \
                ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}-s390x

  docker manifest push ${IMG_REGISTRY_HOST}/${IMG_REGISTRY_ORG}/${OPERATOR_NAME}-catalog:${tag}
done
