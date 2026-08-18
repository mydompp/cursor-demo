locals {
  datadog_env = yamldecode(<<-YAML
    - name: DD_AUTOCONFIG_INCLUDE_FEATURES
      value: "containerd"
    - name: DD_DISABLE_CLUSTER_NAME_TAG_KEY
      value: "true"
    - name: DD_DD_LOGS_CONFIG_TAGGER_WARMUP_DURATION
      value: "5"
    - name: DD_LOGS_CONFIG_EXPECTED_TAGS_DURATION
      value: "10m"
    - name: DD_LOGS_CONFIG_CLOSE_TIMEOUT
      value: "300"
  YAML
  )

  datadog_confd = yamldecode(<<-YAML
    disk.yaml: |-
      init_config:
      instances:
        - use_mount: false
          file_system_exclude:
            - autofs$
          mount_point_exclude:
            - /proc/sys/fs/binfmt_misc
            - /host/proc/sys/fs/binfmt_misc
  YAML
  )

  datadog_node_labels_as_tags = yamldecode(<<-YAML
    beta.kubernetes.io/instance-type: aws-instance-type
    kubernetes.io/role: kube_role
  YAML
  )

  datadog_namespace_labels_as_tags = yamldecode(<<-YAML
    platform_version: platform_version
  YAML
  )

  cluster_agent_env = yamldecode(<<-YAML
    - name: DD_CLUSTER_CHECKS_WARMUP_DURATION
      value: "600"
  YAML
  )

  cluster_agent_tolerations = yamldecode(<<-YAML
    - key: "taint_for_system"
      operator: "Exists"
      effect: "NoSchedule"
  YAML
  )

  agents_tolerations = yamldecode(<<-YAML
    - operator: Exists
  YAML
  )

  agents_affinity = yamldecode(<<-YAML
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: instance
                operator: NotIn
                values:
                  - on-demand
                  - on-demand-spot
                  - on-demand-e2e
                  - on-demand-arm
                  - on-demand-spot-arm
  YAML
  )

  container_resources = yamldecode(<<-YAML
    agent:
      requests: { cpu: 150m, memory: 100Mi }
      limits:   { cpu: 200m, memory: 384Mi }
    processAgent:
      requests: { cpu: 100m, memory: 100Mi }
      limits:   { cpu: 100m, memory: 200Mi }
    traceAgent:
      requests: { cpu: 100m, memory: 100Mi }
      limits:   { cpu: 100m, memory: 150Mi }
    systemProbe:
      requests: { cpu: 100m, memory: 100Mi }
      limits:   { cpu: 100m, memory: 512Mi }
    securityAgent:
      requests: { cpu: 100m, memory: 300Mi }
      limits:   { cpu: 100m, memory: 300Mi }
    initContainers:
      requests: { cpu: 100m, memory: 100Mi }
      limits:   { cpu: 100m, memory: 200Mi }
  YAML
  )

  cluster_agent_resources = yamldecode(<<-YAML
    requests: { cpu: 100m, memory: 256Mi }
    limits:   { cpu: 400m, memory: 2G }
  YAML
  )

  cluster_checks_runner_resources = yamldecode(<<-YAML
    requests: { cpu: 150m, memory: 100Mi }
    limits:   { cpu: 200m, memory: 500Mi }
  YAML
  )

  cluster_checks_runner_tolerations = local.cluster_agent_tolerations

  trace_agent_env = yamldecode(<<-YAML
    - name: DD_APM_IGNORE_RESOURCES
      value: "${var.datadog_apmIgnoreResources}"
    - name: DD_APM_FILTER_TAGS_REJECT
      value: "${var.datadog_apmTagReject}"
    - name: DD_APM_MAX_EPS
      value: "${var.datadog_apmMaxEventsPerSecond}"
    - name: DD_APM_TARGET_TPS
      value: "${var.datadog_apmMaxTracesPerSecond}"
  YAML
  )

  datadog_agent_custom_config = yamldecode(<<-YAML
    listeners:
      - name: kubelet
    config_providers:
      - name: kubelet
        polling: true
      - name: docker
        polling: true

    dogstatsd_mapper_profiles:
      - name: airflow
        prefix: "airflow."
        mappings:
          - match: "airflow.*_start"
            name: "airflow.job.start"
            tags:
              job_name: "$1"
          - match: "airflow.*_end"
            name: "airflow.job.end"
            tags:
              job_name: "$1"
          - match: "airflow.*_heartbeat_failure"
            name: "airflow.job.heartbeat.failure"
            tags:
              job_name: "$1"
          - match: "airflow.operator_failures_*"
            name: "airflow.operator_failures"
            tags:
              operator_name: "$1"
          - match: "airflow.operator_successes_*"
            name: "airflow.operator_successes"
            tags:
              operator_name: "$1"
          - match: 'airflow\.dag_processing\.last_runtime\.(.*)'
            match_type: "regex"
            name: "airflow.dag_processing.last_runtime"
            tags:
              dag_file: "$1"
          - match: 'airflow\.dag_processing\.last_run\.seconds_ago\.(.*)'
            match_type: "regex"
            name: "airflow.dag_processing.last_run.seconds_ago"
            tags:
              dag_file: "$1"
          - match: 'airflow\.dag\.loading-duration\.(.*)'
            match_type: "regex"
            name: "airflow.dag.loading_duration"
            tags:
              dag_file: "$1"
          - match: "airflow.dagrun.*.first_task_scheduling_delay"
            name: "airflow.dagrun.first_task_scheduling_delay"
            tags:
              dag_id: "$1"
          - match: "airflow.pool.open_slots.*"
            name: "airflow.pool.open_slots"
            tags:
              pool_name: "$1"
          - match: "airflow.pool.queued_slots.*"
            name: "airflow.pool.queued_slots"
            tags:
              pool_name: "$1"
          - match: "airflow.pool.running_slots.*"
            name: "airflow.pool.running_slots"
            tags:
              pool_name: "$1"
          - match: "airflow.pool.used_slots.*"
            name: "airflow.pool.used_slots"
            tags:
              pool_name: "$1"
          - match: "airflow.pool.starving_tasks.*"
            name: "airflow.pool.starving_tasks"
            tags:
              pool_name: "$1"
          - match: 'airflow\.dagrun\.dependency-check\.(.*)'
            match_type: "regex"
            name: "airflow.dagrun.dependency_check"
            tags:
              dag_id: "$1"
          - match: 'airflow\.dag\.(.*)\.([^.]*)\.duration'
            match_type: "regex"
            name: "airflow.dag.task.duration"
            tags:
              dag_id: "$1"
              task_id: "$2"
          - match: 'airflow\.dag_processing\.last_duration\.(.*)'
            match_type: "regex"
            name: "airflow.dag_processing.last_duration"
            tags:
              dag_file: "$1"
          - match: 'airflow\.dagrun\.duration\.success\.(.*)'
            match_type: "regex"
            name: "airflow.dagrun.duration.success"
            tags:
              dag_id: "$1"
          - match: 'airflow\.dagrun\.duration\.failed\.(.*)'
            match_type: "regex"
            name: "airflow.dagrun.duration.failed"
            tags:
              dag_id: "$1"
          - match: 'airflow\.dagrun\.schedule_delay\.(.*)'
            match_type: "regex"
            name: "airflow.dagrun.schedule_delay"
            tags:
              dag_id: "$1"
          - match: 'airflow.scheduler.tasks.running'
            name: "airflow.scheduler.tasks.running"
          - match: 'airflow.scheduler.tasks.starving'
            name: "airflow.scheduler.tasks.starving"
          - match: 'airflow.sla_email_notification_failure'
            name: 'airflow.sla_email_notification_failure'
          - match: 'airflow\.task_removed_from_dag\.(.*)'
            match_type: "regex"
            name: "airflow.dag.task_removed"
            tags:
              dag_id: "$1"
          - match: 'airflow\.task_restored_to_dag\.(.*)'
            match_type: "regex"
            name: "airflow.dag.task_restored"
            tags:
              dag_id: "$1"
          - match: "airflow.task_instance_created-*"
            name: "airflow.task.instance_created"
            tags:
              task_class: "$1"
          - match: "airflow.ti.start.*.*"
            name: "airflow.ti.start"
            tags:
              dag_id: "$1"
              task_id: "$2"
          - match: "airflow.ti.finish.*.*.*"
            name: "airflow.ti.finish"
            tags:
              dag_id: "$1"
              task_id: "$2"
              state: "$3"
  YAML
  )

  datadog_set = [
    { name = "registry", value = "datadog" },
    { name = "datadog.clusterName", value = local.cluster_domain_zone },
    { name = "datadog.site", value = "datadoghq.eu" },
    { name = "datadog.dd_url", value = "https://app.datadoghq.eu" },
    { name = "datadog.secretBackend.command", value = "/readsecret_multiple_providers.sh" },
    { name = "datadog.secretBackend.refreshInterval", value = "3600" },
    { name = "datadog.dogstatsd.useHostPort", value = "true" },
    { name = "datadog.remoteConfiguration.enabled", value = "false" },
    { name = "datadog.logs.enabled", value = "true" },
    { name = "datadog.logs.containerCollectAll", value = "true" },
    { name = "datadog.logs.autoMultiLineDetection", value = "true" },
    { name = "datadog.apm.socketEnabled", value = var.datadog_apmEnabled },
    { name = "datadog.apm.portEnabled", value = "true" },
    { name = "datadog.asm.threats.enabled", value = var.datadog_asm },
    { name = "datadog.asm.sca.enabled", value = var.datadog_asm },
    { name = "datadog.asm.iast.enabled", value = var.datadog_asm },
    { name = "datadog.criSocketPath", value = "/run/dockershim.sock" },
    { name = "datadog.processAgent.processCollection", value = "true" },
    { name = "datadog.networkMonitoring.enabled", value = var.datadog_networkMonitoring },
    { name = "datadog.traceroute.enabled", value = var.datadog_networkMonitoring },
    { name = "datadog.sbom.containerImage.enabled", value = var.datadog_asm },
    { name = "datadog.securityAgent.compliance.enabled", value = var.datadog_securityAgent },
    { name = "datadog.securityAgent.runtime.enabled", value = var.datadog_securityAgent },
    { name = "datadog.containerExcludeLogs", value = "kube_namespace:.*" },
    { name = "datadog.containerIncludeLogs", value = join(" ", formatlist("kube_namespace:%s", var.datadog_logs_from_namespaces)) },
    { name = "datadog.containerExcludeMetrics", value = "kube_namespace:.*" },
    { name = "datadog.containerIncludeMetrics", value = join(" ", formatlist("kube_namespace:%s", var.datadog_metrics_from_namespaces)) },
    { name = "datadog.operator.enabled", value = "false" },
    { name = "clusterAgent.replicas", value = "2" },
    { name = "clusterAgent.admissionController.enabled", value = "false" },
    { name = "clusterAgent.livenessProbe.initialDelaySeconds", value = "60" },
    { name = "clusterAgent.readinessProbe.initialDelaySeconds", value = "60" },
    { name = "clusterAgent.startupProbe.initialDelaySeconds", value = "60" },
    { name = "agents.image.tagSuffix", value = "jmx" },
    { name = "agents.containers.agent.livenessProbe.initialDelaySeconds", value = "60" },
    { name = "agents.containers.agent.readinessProbe.initialDelaySeconds", value = "60" },
    { name = "agents.containers.agent.startupProbe.initialDelaySeconds", value = "60" },
    { name = "agents.containers.traceAgent.livenessProbe.initialDelaySeconds", value = "60" },
    { name = "agents.useConfigMap", value = "true" },
    { name = "clusterChecksRunner.enabled", value = "true" },
    { name = "clusterChecksRunner.replicas", value = var.datadog_clusterCkeckReplicas },
    { name = "clusterChecksRunner.livenessProbe.initialDelaySeconds", value = "60" },
    { name = "clusterChecksRunner.readinessProbe.initialDelaySeconds", value = "60" },
    { name = "clusterChecksRunner.startupProbe.initialDelaySeconds", value = "60" },
    { name = "operator.datadogGenericResource.enabled", value = "true" },
    { name = "operator.datadogSLO.enabled", value = "true" },
    { name = "operator.datadogCRDs.crds.datadogAgents", value = "false" },
    { name = "remoteConfiguration.enabled", value = "false" },
  ]

  datadog_set_list = [
    { name = "datadog.ignoreAutoConfig", value = ["redisdb", "disk", "coredns"] },
  ]

  datadog_set_sensitive = [
    { name = "datadog.apiKey", value = "api_key" },
    { name = "datadog.appKey", value = "app_key" },
    { name = "clusterAgent.token", value = "cluster_agent_token" },
  ]

  datadog_values = {
    datadog = {
      env                   = local.datadog_env
      confd                 = local.datadog_confd
      nodeLabelsAsTags      = local.datadog_node_labels_as_tags
      namespaceLabelsAsTags = local.datadog_namespace_labels_as_tags
    }
    clusterAgent = {
      image        = { pullSecrets = [{ name = var.image_pull_secret }] }
      env          = local.cluster_agent_env
      resources    = local.cluster_agent_resources
      nodeSelector = { name = "system-node" }
      tolerations  = local.cluster_agent_tolerations
    }
    agents = {
      image             = { pullSecrets = [{ name = var.image_pull_secret }] }
      tolerations       = local.agents_tolerations
      affinity          = local.agents_affinity
      customAgentConfig = local.datadog_agent_custom_config
      containers = {
        agent          = { resources = local.container_resources.agent }
        processAgent   = { resources = local.container_resources.processAgent }
        traceAgent     = { env = local.trace_agent_env, resources = local.container_resources.traceAgent }
        systemProbe    = { resources = local.container_resources.systemProbe }
        securityAgent  = { resources = local.container_resources.securityAgent }
        initContainers = { resources = local.container_resources.initContainers }
      }
    }
    clusterChecksRunner = {
      image        = { pullSecrets = [{ name = var.image_pull_secret }] }
      resources    = local.cluster_checks_runner_resources
      nodeSelector = { name = "system-node" }
      tolerations  = local.cluster_checks_runner_tolerations
    }
  }
}

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = local.ecr_oci_repository
  chart      = "datadog"
  namespace  = "monitoring"
  version    = local.chart_versions["datadog"]
  timeout    = 1200

  values = [yamlencode(local.datadog_values)]

  dynamic "set" {
    for_each = local.datadog_set
    content {
      name  = set.value.name
      value = set.value.value
    }
  }

  dynamic "set_list" {
    for_each = local.datadog_set_list
    content {
      name  = set_list.value.name
      value = set_list.value.value
    }
  }

  dynamic "set_sensitive" {
    for_each = local.datadog_set_sensitive
    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
    }
  }
}
