#!/bin/bash
set -eu
# Simple script to deploy Fluent Operator to a Kubernetes cluster with context already set

LOGGING_NAMESPACE=${LOGGING_NAMESPACE:-fluent}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm upgrade --install fluent-operator --create-namespace -n $LOGGING_NAMESPACE --wait --timeout 60s https://github.com/fluent/fluent-operator/releases/download/v1.0.0/fluent-operator.tgz

echo -e "\n"
kubectl -n $LOGGING_NAMESPACE wait --for=condition=available deployment/fluent-operator --timeout=60s
echo "Please visit https://github.com/fluent/fluent-operator/tree/master/manifests/fluentd to apply the manifests that you want to explore."