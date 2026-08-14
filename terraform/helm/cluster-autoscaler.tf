resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = local.ecr_oci_repository
  chart            = "cluster-autoscaler"
  version          = local.chart_versions["cluster-autoscaler"]
  namespace        = var.namespace
  create_namespace = false
  atomic           = true
  wait             = true

  set {
    name  = "cloudProvider"
    value = "aws"
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = var.cluster_autoscaler_service_account_name
  }
}
