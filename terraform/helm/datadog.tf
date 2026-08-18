
resource "helm_release" "datadog" {
  name                = "datadog"
  repository       = local.ecr_oci_repository
  chart               = "datadog"
  namespace           = "monitoring"
  version             = var.charts_versions.datadog
  timeout             = 1200
  values = [templatefile("${path.module}/values/datadog/values.yaml", {
    clusterName           = local.cluster_domain_zone
    imageRepository       = "datadog"
    imagePullSecret       = var.image_pull_secret
    networkMonitoring     = var.datadog_networkMonitoring
    logsFromNamespaces    = join(" ", formatlist("kube_namespace:%s", var.datadog_logs_from_namespaces))
    metricsFromNamespaces = join(" ", formatlist("kube_namespace:%s", var.datadog_metrics_from_namespaces))
    apmTagReject          = var.datadog_apmTagReject
    apmIgnoreResources    = var.datadog_apmIgnoreResources
    apmMaxEventsPerSecond = var.datadog_apmMaxEventsPerSecond
    apmMaxTracesPerSecond = var.datadog_apmMaxTracesPerSecond
    apmEnabled            = var.datadog_apmEnabled
    asmEnabled            = var.datadog_asm
    securityAgentEnabled  = var.datadog_securityAgent
    clusterCkeckReplicas  = var.datadog_clusterCkeckReplicas
  })]

  set_sensitive = [{
    name  = "datadog.apiKey"
    value = "api_key"
    },
    {
      name  = "datadog.appKey"
      value = "app_key"
    },
    {
      name  = "clusterAgent.token"
      value = "cluster_agent_token"
  }]
}
