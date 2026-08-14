locals {
  alb_pin     = yamldecode(file("${path.module}/../../helm-pins/aws-load-balancer-controller/Chart.yaml"))
  secrets_pin = yamldecode(file("${path.module}/../../helm-pins/secrets-store-csi-driver/Chart.yaml"))
  ca_pin      = yamldecode(file("${path.module}/../../helm-pins/cluster-autoscaler/Chart.yaml"))

  ecr_oci_repository = "oci://${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  chart_versions = {
    aws-load-balancer-controller = one([
      for d in local.alb_pin.dependencies : d.version if d.name == "aws-load-balancer-controller"
    ])
    secrets-store-csi-driver = one([
      for d in local.secrets_pin.dependencies : d.version if d.name == "secrets-store-csi-driver"
    ])
    cluster-autoscaler = one([
      for d in local.ca_pin.dependencies : d.version if d.name == "cluster-autoscaler"
    ])
  }
}
