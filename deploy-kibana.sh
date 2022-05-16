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


# Kibana is provided primarily for visualisation
helm upgrade --install --namespace="$ES_NAMESPACE" --create-namespace --wait kibana elasticsearch/kibana

echo "Kibana deployed, now set up indexes by going to http://localhost:5601/app/management/kibana/indexPatterns after running:"
echo "kubectl port-forward -n elastic svc/kibana-kibana 5601"
