resource "helm_release" "secrets_store_csi_driver" {
  name             = "secrets-store-csi-driver"
  repository       = local.ecr_oci_repository
  chart            = "secrets-store-csi-driver"
  version          = local.chart_versions["secrets-store-csi-driver"]
  namespace        = var.namespace
  create_namespace = false
  atomic           = true
  wait             = true

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  set {
    name  = "linux.providersDir"
    value = "/var/run/secrets-store-csi-providers"
  }
}
