#!/bin/bash

set -eu
# Simple script to provision a Kubernetes cluster using KIND: https://kind.sigs.k8s.io/

# Override with a different name if you want
CLUSTER_NAME=${CLUSTER_NAME:-kubesphere}

if [[ "${INSTALL_KIND:-no}" == "yes" ]]; then
    rm -f ./kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
    chmod a+x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

# Delete the old cluster (if it exists)
kind delete cluster --name="${CLUSTER_NAME}"

kind create cluster --name="${CLUSTER_NAME}" 

echo "Cluster created successfully"
