#!/bin/bash
set -eu
# Simple script to deploy Kafka to a Kubernetes cluster with context already set
KAFKA_NAMESPACE=${KAFKA_NAMESPACE:-kafka}
CLUSTER_NAME=${CLUSTER_NAME:-fluent}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# docker pull quay.io/strimzi/kafka:0.28.0-kafka-3.1.0
# docker pull quay.io/strimzi/operator:0.28.0
# kind load docker-image quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --name fluent
# kind load docker-image quay.io/strimzi/operator:0.28.0 --name fluent

kubectl create ns $KAFKA_NAMESPACE
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n $KAFKA_NAMESPACE
#kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-persistent-single.yaml -n $KAFKA_NAMESPACE
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
spec:
  kafka:
    version: 3.1.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      inter.broker.protocol.version: "3.1"
    storage:
      type: ephemeral
  zookeeper:
    replicas: 1
    storage:
      type: ephemeral
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n $KAFKA_NAMESPACE 
