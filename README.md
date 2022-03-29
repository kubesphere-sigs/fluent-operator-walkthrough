# fluent-operator-walkthrough

- [fluent-operator-walkthrough](#fluent-operator-walkthrough)
  - [Create Kind Cluster](#create-kind-cluster)
  - [Startup Log sinks](#startup-log-sinks)
    - [Startup Kafka Cluster](#startup-kafka-cluster)
    - [Startup ES Cluster](#startup-es-cluster)
  - [Install Fluent Operator (Operator only)](#install-fluent-operator-operator-only)
  - [Deploy Fluent Bit or Fluentd](#deploy-fluent-bit-or-fluentd)
    - [Create Fluent Bit Daemonset using FluentBit CRD](#create-fluent-bit-daemonset-using-fluentbit-crd)
    - [Create Fluentd Statefulset using Fluentd CRD](#create-fluentd-statefulset-using-fluentd-crd)
  - [Fluent Bit Only mode](#fluent-bit-only-mode)
    - [Using Fluent Bit to collect docker logs and send to es](#using-fluent-bit-to-collect-docker-logs-and-send-to-es)
    - [Using Fluent Bit to collect k8s logs and send to kafka](#using-fluent-bit-to-collect-k8s-logs-and-send-to-kafka)
  - [Fluent Bit + Fluentd mode](#fluent-bit--fluentd-mode)
    - [Enable Fluent Bit forward plugin](#enable-fluent-bit-forward-plugin)
    - [ClusterFluentdConfig: Fluentd cluster-wide configuration](#clusterfluentdconfig-fluentd-cluster-wide-configuration)
    - [FluentdConfig: Fluentd namespaced-wide configuration](#fluentdconfig-fluentd-namespaced-wide-configuration)
    - [Combining Fluentd cluster-wide and namespaced-wide configuration](#combining-fluentd-cluster-wide-and-namespaced-wide-configuration)
    - [Combining Fluentd cluster-wide output and namespace-wide output for the multi-tenant scenario](#combining-fluentd-cluster-wide-output-and-namespace-wide-output-for-the-multi-tenant-scenario)
    - [Outputing logs to Kafka or Elasticsearch](#outputing-logs-to-kafka-or-elasticsearch)
    - [Using buffer for Fluentd output](#using-buffer-for-fluentd-output)
  - [Fluentd only mode](#fluentd-only-mode)
    - [Use fluentd to receive logs from HTTP and send to stdout](#use-fluentd-to-receive-logs-from-http-and-send-to-stdout)
  - [How to check the configuration and data](#how-to-check-the-configuration-and-data)

## Create Kind Cluster

Following the script "create-kind-cluster.sh" to create a kind cluster named kubesphere，you can change the cluster name as what you wanted.

## Startup Log sinks

### Startup Kafka Cluster

Following the script "deploy-kafka.sh" to deploy a kafka cluster.

### Startup ES Cluster

Following the script "deploy-es.sh" to deploy a es cluster.

## Install Fluent Operator (Operator only)

Following the script "deploy-fluent-operator-raw.sh" to deploy a raw Fluent Operator deployment.

The Fluent Operator works through the defined CRDs. The orchestration engine can start Fluent Bit instances or Fluentd instances and use Secret Object to mount configuration files on which the instances run.

You can find a detailed introduction to CRD at the link below:

- https://github.com/fluent/fluent-operator#fluent-bit
- https://github.com/fluent/fluent-operator#fluentd
  
## Deploy Fluent Bit or Fluentd

### Create Fluent Bit Daemonset using FluentBit CRD
  
```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentbit.fluent.io/v1alpha2
kind: FluentBit
metadata:
  name: fluent-bit
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  image: kubesphere/fluent-bit:v1.8.3
  positionDB:
    hostPath:
      path: /var/lib/fluent-bit/
  resources:
    requests:
      cpu: 10m
      memory: 25Mi
    limits:
      cpu: 500m
      memory: 200Mi
  fluentBitConfigName: fluent-bit-config
  tolerations:
    - operator: Exists
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role.kubernetes.io/edge
            operator: DoesNotExist
EOF
```

### Create Fluentd Statefulset using Fluentd CRD
  
```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 3
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
EOF
```

## Fluent Bit Only mode

### Using Fluent Bit to collect docker logs and send to es

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentbit.fluent.io/v1alpha2
kind: FluentBit
metadata:
  name: fluent-bit
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  image: kubesphere/fluent-bit:v1.8.3
  positionDB:
    hostPath:
      path: /var/lib/fluent-bit/
  resources:
    requests:
      cpu: 10m
      memory: 25Mi
    limits:
      cpu: 500m
      memory: 200Mi
  fluentBitConfigName: fluent-bit-config
  tolerations:
    - operator: Exists
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role.kubernetes.io/edge
            operator: DoesNotExist
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFluentBitConfig
metadata:
  name: fluent-bit-config
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  service:
    parsersFile: parsers.conf
  inputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
  filterSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
  outputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterInput
metadata:
  name: docker
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  systemd:
    tag: service.docker
    path: /var/log/journal
    db: /fluent-bit/tail/docker.db
    dbSync: Normal
    systemdFilter:
      - _SYSTEMD_UNIT=docker.service
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFilter
metadata:
  name: systemd
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  match: service.*
  filters:
  - lua:
      script:
        key: systemd.lua
        name: fluent-bit-lua
      call: add_time
      timeAsTable: true
---
apiVersion: v1
data:
  systemd.lua: |
    function add_time(tag, timestamp, record)
      new_record = {}
      timeStr = os.date("!*t", timestamp["sec"])
      t = string.format("%4d-%02d-%02dT%02d:%02d:%02d.%sZ",
    		timeStr["year"], timeStr["month"], timeStr["day"],
    		timeStr["hour"], timeStr["min"], timeStr["sec"],
    		timestamp["nsec"])
      kubernetes = {}
      kubernetes["pod_name"] = record["_HOSTNAME"]
      kubernetes["container_name"] = record["SYSLOG_IDENTIFIER"]
      kubernetes["namespace_name"] = "kube-system"
      new_record["time"] = t
      new_record["log"] = record["MESSAGE"]
      new_record["kubernetes"] = kubernetes
      return 1, timestamp, new_record
    end
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/component: operator
    app.kubernetes.io/name: fluent-bit-lua
  name: fluent-bit-lua
  namespace: fluent
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterOutput
metadata:
  name: es
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  matchRegex: (?:kube|service)\.(.*)
  es:
    host: elasticsearch-master.elastic.svc
    port: 9200
    generateID: true
    logstashPrefix: ks-logstash-log
    logstashFormat: true
    timeKey: "@timestamp"  
EOF
```

Within a couple of minutes, you should check the results in ES cluster.

> you can refer the following docs to check results.

### Using Fluent Bit to collect k8s logs and send to kafka

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentbit.fluent.io/v1alpha2
kind: FluentBit
metadata:
  name: fluent-bit
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  image: kubesphere/fluent-bit:v1.8.3
  positionDB:
    hostPath:
      path: /var/lib/fluent-bit/
  resources:
    requests:
      cpu: 10m
      memory: 25Mi
    limits:
      cpu: 500m
      memory: 200Mi
  fluentBitConfigName: fluent-bit-config
  tolerations:
    - operator: Exists
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-role.kubernetes.io/edge
            operator: DoesNotExist
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFluentBitConfig
metadata:
  name: fluent-bit-config
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  service:
    parsersFile: parsers.conf
  inputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
  filterSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
  outputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterInput
metadata:
  name: kubelet
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  systemd:
    tag: service.kubelet
    path: /var/log/journal
    db: /fluent-bit/tail/kubelet.db
    dbSync: Normal
    systemdFilter:
      - _SYSTEMD_UNIT=kubelet.service
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterInput
metadata:
  name: tail
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  tail:
    tag: kube.*
    path: /var/log/containers/*.log
    parser: docker
    refreshIntervalSeconds: 10
    memBufLimit: 5MB
    skipLongLines: true
    db: /fluent-bit/tail/pos.db
    dbSync: Normal
---
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFilter
metadata:
  name: systemd
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  match: service.*
  filters:
  - lua:
      script:
        key: systemd.lua
        name: fluent-bit-lua
      call: add_time
      timeAsTable: true
---
apiVersion: v1
data:
  systemd.lua: |
    function add_time(tag, timestamp, record)
      new_record = {}
      timeStr = os.date("!*t", timestamp["sec"])
      t = string.format("%4d-%02d-%02dT%02d:%02d:%02d.%sZ",
    		timeStr["year"], timeStr["month"], timeStr["day"],
    		timeStr["hour"], timeStr["min"], timeStr["sec"],
    		timestamp["nsec"])
      kubernetes = {}
      kubernetes["pod_name"] = record["_HOSTNAME"]
      kubernetes["container_name"] = record["SYSLOG_IDENTIFIER"]
      kubernetes["namespace_name"] = "kube-system"
      new_record["time"] = t
      new_record["log"] = record["MESSAGE"]
      new_record["kubernetes"] = kubernetes
      return 1, timestamp, new_record
    end
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/component: operator
    app.kubernetes.io/name: fluent-bit-lua
  name: fluent-bit-lua
  namespace: fluent
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFilter
metadata:
  name: systemd
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  match: service.*
  filters:
  - lua:
      script:
        key: systemd.lua
        name: fluent-bit-lua
      call: add_time
      timeAsTable: true
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFilter
metadata:
  name: kubernetes
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  match: kube.*
  filters:
  - kubernetes:
      kubeURL: https://kubernetes.default.svc:443
      kubeCAFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      kubeTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      labels: false
      annotations: false
  - nest:
      operation: lift
      nestedUnder: kubernetes
      addPrefix: kubernetes_
  - modify:
      rules:
      - remove: stream
      - remove: kubernetes_pod_id
      - remove: kubernetes_host
      - remove: kubernetes_container_hash
  - nest:
      operation: nest
      wildcard:
      - kubernetes_*
      nestUnder: kubernetes
      removePrefix: kubernetes_
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterOutput
metadata:
  name: kafka
  labels:
    fluentbit.fluent.io/enabled: "false"
    fluentbit.fluent.io/component: logging
spec:
  matchRegex: (?:kube|service)\.(.*)
  kafka:
    brokers: my-cluster-kafka-bootstrap.kafka.svc:9091,my-cluster-kafka-bootstrap.kafka.svc:9092,my-cluster-kafka-bootstrap.kafka.svc:9093
    topics: ks-log
EOF
```

Within a couple of minutes, you should check the results in ES cluster.

> you can refer the following docs to check results.

## Fluent Bit + Fluentd mode

Fluentd acts as a log forward layer that receives logs from Fluent Bit.

### Enable Fluent Bit forward plugin

At first, you should enable the forward plugin in Fluent Bit to send logs to Fluentd.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterOutput
metadata:
  name: fluentd
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/component: logging
spec:
  matchRegex: (?:kube|service)\.(.*)
  forward:
    host: fluentd.fluent.svc
    port: 24224
EOF
```

> Before you applying the manifests, please make the former yamls removed.

And secondly, Fluentd also needs to use the forward input plugin to receive these input logs. This part has been combined into the following examples.

### ClusterFluentdConfig: Fluentd cluster-wide configuration

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
   
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: fluentd-config
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-monitoring-system
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output-es
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log
EOF
```
> Before you applying the manifests, please make the former yamls removed.

### FluentdConfig: Fluentd namespaced-wide configuration

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
   
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: fluentd-config
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  outputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Output
metadata:
  name: fluentd-output-es
  namespace: fluent
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log
EOF
```
> Before you applying the manifests, please make the former yamls removed.

### Combining Fluentd cluster-wide and namespaced-wide configuration

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
   
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: fluentd-config
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-monitoring-system
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: fluentd-config
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output-es
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log
EOF
```
> Before you applying the manifests, please make the former yamls removed.

### Combining Fluentd cluster-wide output and namespace-wide output for the multi-tenant scenario

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
   
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: fluentd-config-user1
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  outputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"
      output.fluentd.fluent.io/user: "user1"
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"
      output.fluentd.fluent.io/role: "log-operator"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: fluentd-config-cluster
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-system
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"
      output.fluentd.fluent.io/scope: "cluster"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Output
metadata:
  name: fluentd-output-user1
  namespace: fluent
  labels:
    output.fluentd.fluent.io/enabled: "true"
    output.fluentd.fluent.io/user: "user1"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log-user1

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output-log-operator
  labels:
    output.fluentd.fluent.io/enabled: "true"
    output.fluentd.fluent.io/role: "log-operator"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log-operator

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output-cluster
  labels:
    output.fluentd.fluent.io/enabled: "true"
    output.fluentd.fluent.io/scope: "cluster"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log
EOF
```
> Before you applying the manifests, please make the former yamls removed.

### Outputing logs to Kafka or Elasticsearch

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: fluentd-config
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-monitoring-system
  clusterFilterSelector:
    matchLabels:
      filter.fluentd.fluent.io/enabled: "true"
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFilter
metadata:
  name: fluentd-filter
  labels:
    filter.fluentd.fluent.io/enabled: "true"
spec: 
  filters: 
  - recordTransformer:
      enableRuby: true
      records:
      - key: kubernetes_ns
        value: ${record["kubernetes"]["namespace_name"]}

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output-kafka
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - kafka:
      brokers: my-cluster-kafka-bootstrap.default.svc:9091,my-cluster-kafka-bootstrap.default.svc:9092,my-cluster-kafka-bootstrap.default.svc:9093
      useEventTime: true
      topicKey: kubernetes_ns
EOF
```
> Before you applying the manifests, please make the former yamls removed.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
   
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: fluentd-config
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-monitoring-system
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output-es
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log
EOF
```
> Before you applying the manifests, please make the former yamls removed.

### Using buffer for Fluentd output

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
  - forward: 
      bind: 0.0.0.0
      port: 24224
  replicas: 3
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: fluentd-config
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-monitoring-system
  clusterFilterSelector:
    matchLabels:
      filter.fluentd.fluent.io/enabled: "true"
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFilter
metadata:
  name: fluentd-filter
  labels:
    filter.fluentd.fluent.io/enabled: "true"
spec: 
  filters: 
  - recordTransformer:
      enableRuby: true
      records:
      - key: kubernetes_ns
        value: ${record["kubernetes"]["namespace_name"]}

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: fluentd-output
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - stdout: {}
    buffer:
      type: file
      path: /buffers/stdout.log
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: ks-logstash-log
    buffer:
      type: file
      path: /buffers/es.log
EOF
```
> Before you applying the manifests, please make the former yamls removed.

## Fluentd only mode

### Use fluentd to receive logs from HTTP and send to stdout

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: Fluentd
metadata:
  name: fluentd-http
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluentd
spec:
  globalInputs:
    - http: 
        bind: 0.0.0.0
        port: 9880
  replicas: 1
  image: kubesphere/fluentd:v1.14.4
  fluentdCfgSelector: 
    matchLabels:
      config.fluentd.fluent.io/enabled: "true"
   
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: fluentd-config
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  filterSelector:
    matchLabels:
      filter.fluentd.fluent.io/enabled: "true"
  outputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Filter
metadata:
  name: fluentd-filter
  namespace: fluent
  labels:
    filter.fluentd.fluent.io/enabled: "true"
spec: 
  filters: 
    - stdout: {}

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Output
metadata:
  name: fluentd-stdout
  namespace: fluent
  labels:
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
    - stdout: {}
EOF
```
> Before you applying the manifests, please make the former yamls removed.

Then you can send logs to the endpoint by using curl:

```
curl -X POST -d 'json={"foo":"bar"}' http://<localhost:9880>/app.log
```
> replace the <localhost:9880> to the actual service or endpoint of fluentd, i.e: fluentd-http.fluent.svc:9880

## How to check the configuration and data

1. See the state of the Fluent Operator:

```bash
kubectl get po -n fluent
```

2. See the generated fluent bit configuration:

```bash
kubectl -n fluent get secrets fluent-bit-config -ojson | jq '.data."fluent-bit.conf"' | awk -F '"' '{printf $2}' | base64 --decode

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
    Name    forward
    Match_Regex    (?:kube|service)\.(.*)
    Host    fluentd.fluent.svc
    Port    24224
```

3. See the generated fluentd configuration:
   
```bash
kubectl -n fluent get secrets fluentd-config -ojson | jq '.data."app.conf"' | awk -F '"' '{printf $2}' | base64 --decode 
---
<source>
  @type  forward
  bind  0.0.0.0
  port  24224
</source>
<match **>
  @id  main
  @type  label_router
  <route>
    @label  @48b7cb809bc2361ba336802a95eca0d4
    <match>
      namespaces  kube-system,kubesphere-monitoring-system
    </match>
  </route>
</match>
<label @48b7cb809bc2361ba336802a95eca0d4>
  <filter **>
    @id  ClusterFluentdConfig-cluster-fluentd-config::cluster::clusterfilter::fluentd-filter-0
    @type  record_transformer
    enable_ruby  true
    <record>
      kubernetes_ns  ${record["kubernetes"]["namespace_name"]}
    </record>
  </filter>
  <match **>
    @id  ClusterFluentdConfig-cluster-fluentd-config::cluster::clusteroutput::fluentd-output-es-0
    @type  elasticsearch
    host  elasticsearch-master.elastic.svc
    logstash_format  true
    logstash_prefix  ks-logstash-log
    port  9200
  </match>
  <match **>
    @id  ClusterFluentdConfig-cluster-fluentd-config::cluster::clusteroutput::fluentd-output-kafka-0
    @type  kafka2
    brokers  my-cluster-kafka-bootstrap.kafka.svc:9091,my-cluster-kafka-bootstrap.kafka.svc:9092,my-cluster-kafka-bootstrap.kafka.svc:9093
    topic_key  kubernetes_ns
    use_event_time  true
    <format>
      @type  json
    </format>
  </match>
</label>
```

4. Query the elastic cluster kubernetes_ns buckets:

```bash
kubectl -n elastic exec -it elasticsearch-master-0 -c elasticsearch --  curl -X GET "localhost:9200/ks-logstash*/_search?pretty" -H 'Content-Type: application/json' -d '{                                                           
   "size" : 0,
   "aggs" : {
      "kubernetes_ns": {
         "terms" : {
           "field": "kubernetes.namespace_name.keyword"
         }
      }
   }
}'
```

> If you don't use fluentd to extract the namspace field, you can use other query API.

5. Check the kafka cluster:
   
```bash
# kubectl -n kafka exec -it my-cluster-kafka-0 -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic <namespace or ks-log>
```

> Replace <namespace or ks-log> to the actual topic.
