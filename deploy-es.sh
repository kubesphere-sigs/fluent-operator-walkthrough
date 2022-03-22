#!/bin/bash
set -eu
# Simple script to deploy Elastic to a Kubernetes cluster with context already set

ES_NAMESPACE=${ES_NAMESPACE:-elastic}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add elasticsearch https://helm.elastic.co || helm repo add elasticsearch https://helm.elastic.co/
helm repo update

helm upgrade --install --namespace="$ES_NAMESPACE" --create-namespace --wait elasticsearch elasticsearch/elasticsearch \
  --set replicas=1,minMasterNodes=1
