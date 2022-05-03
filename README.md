# fluent-operator-walkthrough
<!-- TOC -->

- [fluent-operator-walkthrough](#fluent-operator-walkthrough)
	- [Prerequisite](#prerequisite)
	- [Install Fluent Operator](#install-fluent-operator)
	- [Deploy Fluent Bit and Fluentd](#deploy-fluent-bit-and-fluentd)
		- [Deploy Fluent Bit](#deploy-fluent-bit)
		- [Deploy Fluentd](#deploy-fluentd)
	- [Fluent Bit Only mode](#fluent-bit-only-mode)
		- [Using Fluent Bit to collect kubelet logs and output to Elasticsearch](#using-fluent-bit-to-collect-kubelet-logs-and-output-to-elasticsearch)
		- [Using Fluent Bit to collect K8s application logs and output to Kafka](#using-fluent-bit-to-collect-k8s-application-logs-and-output-to-kafka)
	- [Fluent Bit + Fluentd mode](#fluent-bit--fluentd-mode)
		- [Forward logs from Fluent Bit to Fluentd](#forward-logs-from-fluent-bit-to-fluentd)
		- [Enable Fluentd Forward Input plugin to receive logs from Fluent Bit](#enable-fluentd-forward-input-plugin-to-receive-logs-from-fluent-bit)
		- [ClusterFluentdConfig: Fluentd cluster-wide configuration](#clusterfluentdconfig-fluentd-cluster-wide-configuration)
		- [FluentdConfig: Fluentd namespaced-wide configuration](#fluentdconfig-fluentd-namespaced-wide-configuration)
		- [Use cluster-wide and namespaced-wide FluentdConfig together](#use-cluster-wide-and-namespaced-wide-fluentdconfig-together)
		- [Use cluster-wide and namespaced-wide FluentdConfig together in multi-tenant scenarios](#use-cluster-wide-and-namespaced-wide-fluentdconfig-together-in-multi-tenant-scenarios)
		- [Route logs to different Kafka topics based on namespace](#route-logs-to-different-kafka-topics-based-on-namespace)
		- [Using buffer for Fluentd output](#using-buffer-for-fluentd-output)
	- [Fluentd only mode](#fluentd-only-mode)
		- [Use fluentd to receive logs from HTTP and output to stdout](#use-fluentd-to-receive-logs-from-http-and-output-to-stdout)
	- [How to check the configuration and data](#how-to-check-the-configuration-and-data)

<!-- /TOC -->
## Prerequisite

To get some hands-on experience on the Fluent Operator, you'll need a minikube cluster. You also need to set up a Kafka cluster and an Elasticsearch cluster in this Kind cluster.

```shell
# If you already have a K8s cluster, you can skip installing minikube.
# Please be aware that the fluentbit and fluentd cases in this walkthrough might not work properly in a KinD cluster
# A minikube cluster is recommended if you don't have a K8s cluster.
# Setup a minikube cluster on the linux
./create-minikube-cluster.sh
# Setup a minikube cluster on the mac
./create-minikube-cluster-for-mac.sh

# Setup a Kafka cluster in the kafka namespace
./deploy-kafka.sh

# Setup an Elasticsearch cluster in the elastic namespace
# run 'export INSTALL_HELM=yes' first if helm is not installed
./deploy-es.sh
```
>Note:
> If you fail in mac execution, you may have to remove the old minikube links and link the newly installed binary:
> <br>brew unlink minikube<br>
> <br>brew link minikube<br>
> Reference: https://minikube.sigs.k8s.io/docs/start/

## Install Fluent Operator

Fluent Operator controls the lifecycle of the Fluent Bit and Fluentd. You can use the following script to launch the Fluent Operator in the `fluent` namespace:

```shell
./deploy-fluent-operator.sh
```

You can find more details of the Fluent Bit and Fluentd CRDs in the links below:

- https://github.com/fluent/fluent-operator#fluent-bit
- https://github.com/fluent/fluent-operator#fluentd
  
## Deploy Fluent Bit and Fluentd

Both Fluent Bit and Fluentd are defined as CRDs in Fluent Operator, you can create the Fluent Bit DaemonSet or the Fluentd StatefulSet by declaring FluentBit or Fluentd CR.

### Deploy Fluent Bit

The `FluentBit` CR works together with `ClusterFluentBitConfig` and they should be created together.
The following `FluentBit` CR is just an example. To deply the actually Fluent Bit DaemonSet, please refer to the [Using Fluent Bit to collect kubelet logs and output to Elasticsearch](#using-fluent-bit-to-collect-kubelet-logs-and-output-to-elasticsearch) and [Using Fluent Bit to collect K8s application logs and output to Kafka](#using-fluent-bit-to-collect-k8s-application-logs-and-output-to-kafka) sections.
  
```yaml
apiVersion: fluentbit.fluent.io/v1alpha2
kind: FluentBit
metadata:
  name: fluent-bit
  namespace: fluent
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  image: kubesphere/fluent-bit:v1.8.11
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
  fluentBitConfigName: fluent-bit-only-config
  tolerations:
    - operator: Exists
```

### Deploy Fluentd
  
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

Now we've setup FluentBit and Flunetd, let's collect, process, and send logs to various sinks in the next few steps.

## Fluent Bit Only mode

Fluent Bit is light-weighed, you can only use Fluent Bit to process logs.

### Using Fluent Bit to collect kubelet logs and output to Elasticsearch

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
  image: kubesphere/fluent-bit:v1.8.11
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
  fluentBitConfigName: fluent-bit-only-config
  tolerations:
    - operator: Exists
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFluentBitConfig
metadata:
  name: fluent-bit-only-config
  labels:
    app.kubernetes.io/name: fluent-bit
spec:
  service:
    parsersFile: parsers.conf
  inputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
      fluentbit.fluent.io/mode: "fluentbit-only"
  filterSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
      fluentbit.fluent.io/mode: "fluentbit-only"
  outputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
      fluentbit.fluent.io/mode: "fluentbit-only"
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterInput
metadata:
  name: kubelet
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/mode: "fluentbit-only"
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
kind: ClusterFilter
metadata:
  name: systemd
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/mode: "fluentbit-only"
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
    fluentbit.fluent.io/mode: "fluentbit-only"
spec:
  matchRegex: (?:kube|service)\.(.*)
  es:
    host: elasticsearch-master.elastic.svc
    port: 9200
    generateID: true
    logstashPrefix: fluent-log-fb-only
    logstashFormat: true
    timeKey: "@timestamp"  
EOF
```

You'll see the FluentBit DaemonSet up and running with other CRs:

```shell
kubectl -n fluent get daemonset
kubectl -n fluent get fluentbit
kubectl -n fluent get clusterfluentbitconfig
kubectl -n fluent get clusterinput.fluentbit.fluent.io
kubectl -n fluent get clusterfilter.fluentbit.fluent.io
kubectl -n fluent get clusteroutput.fluentbit.fluent.io
```

Within a couple of minutes, you can double check the results in the Elasticsearch cluster.

> To double check the output, please refer to [this guide](#how-to-check-the-configuration-and-data).

### Using Fluent Bit to collect K8s application logs and output to Kafka

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
  image: kubesphere/fluent-bit:v1.8.11
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
      fluentbit.fluent.io/mode: "k8s"
  filterSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
      fluentbit.fluent.io/mode: "k8s"
  outputSelector:
    matchLabels:
      fluentbit.fluent.io/enabled: "true"
      fluentbit.fluent.io/mode: "k8s"
---
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterInput
metadata:
  name: tail
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/mode: "k8s"
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
apiVersion: fluentbit.fluent.io/v1alpha2
kind: ClusterFilter
metadata:
  name: kubernetes
  labels:
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/mode: "k8s"
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
    fluentbit.fluent.io/enabled: "true"
    fluentbit.fluent.io/mode: "k8s"
spec:
  matchRegex: (?:kube|service)\.(.*)
  kafka:
    brokers: my-cluster-kafka-bootstrap.kafka.svc:9091,my-cluster-kafka-bootstrap.kafka.svc:9092,my-cluster-kafka-bootstrap.kafka.svc:9093
    topics: fluent-log
EOF
```

You'll see the FluentBit DaemonSet up and running with other CRs:

```shell
kubectl -n fluent get daemonset
kubectl -n fluent get fluentbit
kubectl -n fluent get clusterfluentbitconfig
kubectl -n fluent get clusterinput.fluentbit.fluent.io
kubectl -n fluent get clusterfilter.fluentbit.fluent.io
kubectl -n fluent get clusteroutput.fluentbit.fluent.io
```

Within a couple of minutes, you can double check the output in the Kafka cluster.

> To double check the output, please refer to [this guide](#how-to-check-the-configuration-and-data).

## Fluent Bit + Fluentd mode

With its rich plugins, Fluentd acts as a log aggregation layer and is able to perform more advanced log processing.
You can forward logs from Fluent Bit to Fluentd with ease using Fluent Operator.

### Forward logs from Fluent Bit to Fluentd

To forward logs from Fluent Bit to Fluentd, you'll need to enable the Fluent Bit forward plugin as below:

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

### Enable Fluentd Forward Input plugin to receive logs from Fluent Bit

The Fluentd forward Input plugin has been enabled by default when you deploy Fluentd in the previous step, so you needn't to do anything to enable it now.

```yaml
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
```

### ClusterFluentdConfig: Fluentd cluster-wide configuration

You can send logs Fluentd received from Fluent Bit to a cluster-wide sink defined by a `ClusterOutput`.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: cluster-fluentd-config
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - default
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/scope: "cluster"
      output.fluentd.fluent.io/enabled: "true"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: cluster-fluentd-output-es
  labels:
    output.fluentd.fluent.io/scope: "cluster"
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: fluent-log-cluster-fd
EOF
```

You'll see the Fluentd StatefulSet up and running with other CRs:

```shell
kubectl -n fluent get statefulset
kubectl -n fluent get fluentd
kubectl -n fluent get clusterfluentdconfig.fluentd.fluent.io
kubectl -n fluent get clusteroutput.fluentd.fluent.io
```

### FluentdConfig: Fluentd namespaced-wide configuration

You can send logs Fluentd received from Fluent Bit to a namespace-wide sink defined by a `Output`.
Only logs in the same namespace as `FluentdConfig` will be sent to the `Output`.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: namespace-fluentd-config
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  outputSelector:
    matchLabels:
      output.fluentd.fluent.io/scope: "namespace"
      output.fluentd.fluent.io/enabled: "true"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Output
metadata:
  name: namespace-fluentd-output-es
  namespace: fluent
  labels:
    output.fluentd.fluent.io/scope: "namespace"
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: fluent-log-namespace-fd
EOF
```

You'll see the Fluentd CRs created:

```shell
kubectl -n fluent get fluentdconfig
kubectl -n fluent get output.fluentd.fluent.io
```

### Use cluster-wide and namespaced-wide FluentdConfig together

You can use `FluentdConfig` and `ClusterFluentdConfig` together like below.
The `FluentdConfig` will send log of the `fluent` namespace to the `ClusterOutput`
The `ClusterFluentdConfig` will send log of the global `watchedNamespaces` to the `ClusterOutput`

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: cluster-fluentd-config-hybrid
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - default
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/scope: "hybrid"
      output.fluentd.fluent.io/enabled: "true"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: namespace-fluentd-config-hybrid
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/scope: "hybrid"
      output.fluentd.fluent.io/enabled: "true"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: cluster-fluentd-output-es-hybrid
  labels:
    output.fluentd.fluent.io/scope: "hybrid"
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: fluent-log-hybrid-fd
EOF
```

You'll see the Fluentd CRs created:

```shell
kubectl -n fluent get clusterfluentdconfig
kubectl -n fluent get fluentdconfig
kubectl -n fluent get clusteroutput.fluentd.fluent.io
```

### Use cluster-wide and namespaced-wide FluentdConfig together in multi-tenant scenarios

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: FluentdConfig
metadata:
  name: namespace-fluentd-config-user1
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
      output.fluentd.fluent.io/user: "user1"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: cluster-fluentd-config-cluster-only
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - kubesphere-system
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"
      output.fluentd.fluent.io/scope: "cluster-only"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Output
metadata:
  name: namespace-fluentd-output-user1
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
      logstashPrefix: fluent-log-user1-fd
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: cluster-fluentd-output-user1
  labels:
    output.fluentd.fluent.io/enabled: "true"
    output.fluentd.fluent.io/user: "user1"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: fluent-log-cluster-user1-fd
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterOutput
metadata:
  name: cluster-fluentd-output-cluster-only
  labels:
    output.fluentd.fluent.io/enabled: "true"
    output.fluentd.fluent.io/scope: "cluster-only"
spec: 
  outputs: 
  - elasticsearch:
      host: elasticsearch-master.elastic.svc
      port: 9200
      logstashFormat: true
      logstashPrefix: fluent-log-cluster-only-fd
EOF
```

You'll see the Fluentd CRs created:

```shell
kubectl -n fluent get clusterfluentdconfig
kubectl -n fluent get fluentdconfig
kubectl -n fluent get output.fluentd.fluent.io
kubectl -n fluent get clusteroutput.fluentd.fluent.io
```

### Route logs to different Kafka topics based on namespace

You can use Fluentd filter to distribute logs to different topics based on namespace.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: cluster-fluentd-config-kafka
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - default
  clusterFilterSelector:
    matchLabels:
      filter.fluentd.fluent.io/type: "k8s"
      filter.fluentd.fluent.io/enabled: "true"
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/type: "kafka"
      output.fluentd.fluent.io/enabled: "true"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFilter
metadata:
  name: cluster-fluentd-filter-k8s
  labels:
    filter.fluentd.fluent.io/type: "k8s"
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
  name: cluster-fluentd-output-kafka
  labels:
    output.fluentd.fluent.io/type: "kafka"
    output.fluentd.fluent.io/enabled: "true"
spec: 
  outputs: 
  - kafka:
      brokers: my-cluster-kafka-bootstrap.default.svc:9091,my-cluster-kafka-bootstrap.default.svc:9092,my-cluster-kafka-bootstrap.default.svc:9093
      useEventTime: true
      topicKey: kubernetes_ns
EOF
```

You'll see the Fluentd CRs created:

```shell
kubectl -n fluent get clusterfluentdconfig
kubectl -n fluent get clusterfilter.fluentd.fluent.io
kubectl -n fluent get clusteroutput.fluentd.fluent.io
```

### Using buffer for Fluentd output

You can add a buffer to cache logs for the output plugins.

```shell
cat <<EOF | kubectl apply -f -
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFluentdConfig
metadata:
  name: cluster-fluentd-config-buffer
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  watchedNamespaces: 
  - kube-system
  - default
  clusterFilterSelector:
    matchLabels:
      filter.fluentd.fluent.io/type: "buffer"
      filter.fluentd.fluent.io/enabled: "true"
  clusterOutputSelector:
    matchLabels:
      output.fluentd.fluent.io/type: "buffer"      
      output.fluentd.fluent.io/enabled: "true"
---
apiVersion: fluentd.fluent.io/v1alpha1
kind: ClusterFilter
metadata:
  name: cluster-fluentd-filter-buffer
  labels:
    filter.fluentd.fluent.io/type: "buffer"
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
  name: cluster-fluentd-output-buffer
  labels:
    output.fluentd.fluent.io/type: "buffer"      
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
      logstashPrefix: fluent-log-buffer-fd
    buffer:
      type: file
      path: /buffers/es.log
EOF
```

You'll see the Fluentd CRs created:

```shell
kubectl -n fluent get clusterfluentdconfig
kubectl -n fluent get clusterfilter.fluentd.fluent.io
kubectl -n fluent get clusteroutput.fluentd.fluent.io
```

## Fluentd only mode

### Use fluentd to receive logs from HTTP and output to stdout

You can use Fluentd only to receive logs via HTTP.

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
  name: fluentd-only-config
  namespace: fluent
  labels:
    config.fluentd.fluent.io/enabled: "true"
spec:
  filterSelector:
    matchLabels:
      filter.fluentd.fluent.io/mode: "fluentd-only"
      filter.fluentd.fluent.io/enabled: "true"
  outputSelector:
    matchLabels:
      output.fluentd.fluent.io/enabled: "true"
      output.fluentd.fluent.io/mode: "fluentd-only"

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Filter
metadata:
  name: fluentd-only-filter
  namespace: fluent
  labels:
    filter.fluentd.fluent.io/mode: "fluentd-only"
    filter.fluentd.fluent.io/enabled: "true"
spec: 
  filters: 
    - stdout: {}

---
apiVersion: fluentd.fluent.io/v1alpha1
kind: Output
metadata:
  name: fluentd-only-stdout
  namespace: fluent
  labels:
    output.fluentd.fluent.io/enabled: "true"
    output.fluentd.fluent.io/mode: "fluentd-only"
spec: 
  outputs: 
    - stdout: {}
EOF
```

You'll see the Fluentd CRs created:

```shell
kubectl -n fluent get fluentd
kubectl -n fluent get fluentdconfig
kubectl -n fluent get filter.fluentd.fluent.io
kubectl -n fluent get output.fluentd.fluent.io
```

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
      namespaces  kube-system,default
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
    logstash_prefix  fluent-log
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

4. If you chose to forward the logs to Elasticsearch in the previous steps, you could query the elastic cluster kubernetes_ns buckets:

```bash
kubectl -n elastic exec -it elasticsearch-master-0 -c elasticsearch --  curl -X GET "localhost:9200/fluent-log*/_search?pretty" -H 'Content-Type: application/json' -d '{                                                           
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

5. You could also query the index of Elasticsearch. You will find that a new index has been created by fluent operator.

```bash
kubectl -n elastic exec -it elasticsearch-master-0 -c elasticsearch -- curl 'localhost:9200/_cat/indices?v'
health status index                         uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .geoip_databases              j9rTaGpxQiyEt2X0PlAxwA   1   0         40            0       38mb           38mb
yellow open   fluent-log-fb-only-2022.05.03 83TjPvd1Tu-lP4fsIPdZ8A   1   1        145            0    157.2kb        157.2kb
```

6. If you chose to forward the logs to Kafka in the previous steps, you could query the kafka cluster and its topic:
   
```bash
# kubectl -n kafka exec -it my-cluster-kafka-0 -- bin/kafka-console-consumer.sh --bootstrap-server my-cluster-kafka-bootstrap:9092 --topic <namespace or fluent-log>
```

> Replace <namespace or fluent-log> to the actual topic.
