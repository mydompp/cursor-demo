resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = local.ecr_oci_repository
  chart            = "aws-load-balancer-controller"
  version          = local.chart_versions["aws-load-balancer-controller"]
  namespace        = var.namespace
  create_namespace = false
  atomic           = true
  wait             = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = var.alb_controller_service_account_name
  }
}
