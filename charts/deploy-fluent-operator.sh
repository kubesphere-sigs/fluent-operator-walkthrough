#!/bin/bash
set -eu
# Simple script to deploy Fluent Operator to a Kubernetes cluster with context already set

LOGGING_NAMESPACE=${LOGGING_NAMESPACE:-fluent}
SET_FLAGS=""

ELASTIC_SERVICE="elasticsearch-master.elastic.svc"
KAFKA_BROKERS='my-cluster-kafka-bootstrap.kafka.svc:9091\,my-cluster-kafka-bootstrap.kafka.svc:9092\,my-cluster-kafka-bootstrap.kafka.svc:9093'

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if [[ "${ENABLE_K8S:-no}" == "yes" ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L7
    # Collect k8s logs through Fluent Bit.
    SET_FLAGS="${SET_FLAGS} --set Kubernetes=true"
fi

if [[ "${CONTAINER_RUNTIME:-}" != "" ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L6
    SET_FLAGS="${SET_FLAGS} --set containerRuntime=$CONTAINER_RUNTIME"
fi

if [[ "${ENABLE_FLUENTD:-no}" == "no" && "${ENABLE_ES:-no}" == "yes"  ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L73
    SET_FLAGS="${SET_FLAGS} --set fluentbit.output.es.enable=true --set fluentbit.output.es.host=$ELASTIC_SERVICE"
fi

if [[ "${ENABLE_FLUENTD:-no}" == "no" && "${ENABLE_KAFKA:-no}" == "yes" ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L73
    SET_FLAGS="${SET_FLAGS} --set fluentbit.output.kafka.enable=true --set fluentbit.output.kafka.brokers=$KAFKA_BROKERS"
fi

if [[ "${ENABLE_FLUENTD:-no}" == "yes" ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L73
    SET_FLAGS="${SET_FLAGS} --set fluentd.enable=true"
fi

if [[ "${ENABLE_FLUENTD:-no}" == "yes" && "${ENABLE_ES:-no}" == "yes" ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L73
    SET_FLAGS="${SET_FLAGS} --set fluentd.output.es.enable=true --set fluentd.output.es.host=$ELASTIC_SERVICE"
fi

if [[ "${ENABLE_FLUENTD:-no}" == "yes" && "${ENABLE_KAFKA:-no}" == "yes" ]]; then
    # See https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml#L73
    SET_FLAGS="${SET_FLAGS} --set fluentd.output.kafka.enable=true --set fluentd.output.kafka.brokers=$KAFKA_BROKERS"
fi

helm upgrade --install fluent-operator --create-namespace -n $LOGGING_NAMESPACE --wait --timeout 60s https://github.com/fluent/fluent-operator/releases/download/v1.0.0-rc.0/fluent-operator.tgz ${SET_FLAGS}

echo -e "\n"
kubectl -n $LOGGING_NAMESPACE wait --for=condition=available deployment/fluent-operator --timeout=60s
echo "Please visit https://github.com/fluent/fluent-operator/tree/master/manifests/fluentd to apply the manifests that you want to explore."