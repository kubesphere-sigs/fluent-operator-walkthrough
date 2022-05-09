#!/bin/bash
# Copyright 2021 Calyptia, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file  except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the  License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -eu
# Simple script to deploy Loki to a Kubernetes cluster with context already set
LOKI_NAMESPACE=${LOKI_NAMESPACE:-loki}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add grafana https://grafana.github.io/helm-charts || helm repo add grafana https://grafana.github.io/helm-charts/
helm repo update

# Add Loki stack via helm chart in a separate namespace
helm upgrade --install loki --namespace="$LOKI_NAMESPACE" --create-namespace --wait grafana/loki-stack \
  --set fluent-bit.enabled=false,promtail.enabled=false,grafana.enabled=true,prometheus.enabled=false

echo "Loki stack deployed, use loki.$LOKI_NAMESPACE for Fluent Bit configuration inside K8S - outside requires ingress set up."
echo
echo "To port forward Grafana to http://localhost:3000 'kubectl port-forward --namespace $LOKI_NAMESPACE service/loki-grafana 3000:80'"
echo "Credentials are "
echo -n "admin:"
kubectl get secret --namespace "$LOKI_NAMESPACE" loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
