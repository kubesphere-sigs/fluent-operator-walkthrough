# fluent-operator-devtools

Fluent Operator Devtools

## Create Kind Cluster

Following the script "create-kind-cluster.sh" to create a kind cluster named kubesphere，you can change the cluster name as what you wanted:

```bash
#!/bin/bash
set -eu

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
```

## Startup Storage

### Startup Kafka Cluster

Following the script "deploy-kafka.sh" to deploy a kafka cluster:

```bash
#!/bin/bash
set -eu

KAFKA_NAMESPACE=${KAFKA_NAMESPACE:-kafka}
CLUSTER_NAME=${CLUSTER_NAME:-kubesphere}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# docker pull quay.io/strimzi/kafka:0.28.0-kafka-3.1.0
# docker pull quay.io/strimzi/operator:0.28.0
# kind load docker-image quay.io/strimzi/kafka:0.28.0-kafka-3.1.0 --name kubesphere
# kind load docker-image quay.io/strimzi/operator:0.28.0 --name kubesphere

kubectl create ns $KAFKA_NAMESPACE
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n $KAFKA_NAMESPACE
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-persistent-single.yaml -n $KAFKA_NAMESPACE
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n $KAFKA_NAMESPACE
```

### Startup ES Cluster

Following the script "deploy-es.sh" to deploy a es cluster:

```bash
#!/bin/bash
set -eu

ES_NAMESPACE=${ES_NAMESPACE:-elastic}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add elasticsearch https://helm.elastic.co || helm repo add elasticsearch https://helm.elastic.co/
helm repo update

helm upgrade --install --namespace="$ES_NAMESPACE" --create-namespace --wait elasticsearch elasticsearch/elasticsearch \
  --set replicas=1,minMasterNodes=1
```

## Startup Fluent Operator

### Fluent Bit Only

#### Installation

Start up the Fluent Operator with Fluent Bit log pipeline only:

```bash
export ENABLE_K8S=yes && export ENABLE_FLUENTD=no && export ENABLE_ES=yes && export ENABLE_KAFKA=yes && chmod +x ./deploy-fluent-operator.sh && bash ./deploy-fluent-operator.sh
```

See the state of the Fluent Operator:

```bash
# kubectl get po -n kubesphere-logging-system
# kubectl -n kubesphere-logging-system get clusterfluentbitconfigs.fluentbit.fluent.io 
```

See the generate configuration:

```
# kubectl -n kubesphere-logging-system get secrets fluent-bit-config -ojson | jq '.data."fluent-bit.conf"' | awk -F '"' '{printf $2}' | base64 --decode
[Service]
    Parsers_File    parsers.conf
[Input]
    Name    systemd
    Path    /var/log/journal
    DB    /fluent-bit/tail/docker.db
    DB.Sync    Normal
    Tag    service.docker
    Systemd_Filter    _SYSTEMD_UNIT=docker.service
[Input]
    Name    systemd
    Path    /var/log/journal
    DB    /fluent-bit/tail/kubelet.db
    DB.Sync    Normal
    Tag    service.kubelet
    Systemd_Filter    _SYSTEMD_UNIT=kubelet.service
[Input]
    Name    tail
    Path    /var/log/containers/*.log
    Refresh_Interval    10
    Skip_Long_Lines    true
    DB    /fluent-bit/tail/pos.db
    DB.Sync    Normal
    Mem_Buf_Limit    5MB
    Parser    docker
    Tag    kube.*
[Filter]
    Name    lua
    Match    kube.*
    script    /fluent-bit/config/containerd.lua
    call    containerd
    time_as_table    true
[Filter]
    Name    kubernetes
    Match    kube.*
    Kube_URL    https://kubernetes.default.svc:443
    Kube_CA_File    /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File    /var/run/secrets/kubernetes.io/serviceaccount/token
    Labels    false
    Annotations    false
[Filter]
    Name    nest
    Match    kube.*
    Operation    lift
    Nested_under    kubernetes
    Add_prefix    kubernetes_
[Filter]
    Name    modify
    Match    kube.*
    Remove    stream
    Remove    kubernetes_pod_id
    Remove    kubernetes_host
    Remove    kubernetes_container_hash
[Filter]
    Name    nest
    Match    kube.*
    Operation    nest
    Wildcard    kubernetes_*
    Nest_under    kubernetes
    Remove_prefix    kubernetes_
[Filter]
    Name    lua
    Match    service.*
    script    /fluent-bit/config/systemd.lua
    call    add_time
    time_as_table    true
[Output]
    Name    es
    Match_Regex    (?:kube|service)\.(.*)
    Host    elasticsearch-master.elastic.svc
    Port    9200
    Logstash_Format    true
    Logstash_Prefix    ks-logstash-log
    Time_Key    @timestamp
    Generate_ID    true
[Output]
    Name    kafka
    Match_Regex    (?:kube|service)\.(.*)
    Brokers    <kafka broker list like xxx.xxx.xxx.xxx:9092,yyy.yyy.yyy.yyy:9092>
    Topics    ks-log
```

