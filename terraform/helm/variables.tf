variable "aws_account_id" {
  description = "AWS account that hosts the private ECR Helm chart repositories."
  type        = string
}

variable "aws_region" {
  description = "AWS region of the EKS cluster and ECR registry."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded EKS cluster CA certificate."
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID for aws-load-balancer-controller (required when IMDS is unavailable)."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the community chart releases."
  type        = string
  default     = "kube-system"
}

variable "alb_controller_service_account_name" {
  description = "Pre-created IRSA service account for aws-load-balancer-controller."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "cluster_autoscaler_service_account_name" {
  description = "Pre-created IRSA service account for cluster-autoscaler."
  type        = string
  default     = "cluster-autoscaler"
}

locals {
  cluster_name        = "dev"
  cluster_domain_zone = "${local.cluster_name}.markets.tech"
  repository_username = "username"
  repository_password = "password"
}

variable "environment" {
  type = string
}




variable "image_pull_secret" {
  type    = string
  default = "docker-registry"
}

variable "datadog_networkMonitoring" {
  default     = "false"
  type        = string
  description = "Enable network monitoring for k8s cluster"
}

variable "datadog_apmIgnoreResources" {
  default     = "GET /monitor/health,GET /actuator/health"
  type        = string
  description = "Reject AMP traces by tag"
}

variable "datadog_apmTagReject" {
  default     = "http.useragent:ELB-HealthChecker/2.0"
  type        = string
  description = "Reject AMP traces by tag"
}

variable "datadog_apmMaxEventsPerSecond" {
  default     = "600"
  type        = string
  description = "Maximum number of APM events per second to sample"
}

variable "datadog_apmMaxTracesPerSecond" {
  default     = "10"
  description = "Maximum number of APM traces per second to sample"
  type        = string
}

variable "datadog_logs_from_namespaces" {
  default     = ["monitoring"]
  type        = list(string)
  description = "Datadog collect logs from list of namespaces."
}

variable "datadog_metrics_from_namespaces" {
  default     = ["monitoring"]
  type        = list(string)
  description = "Datadog collect metrics from list of namespaces."
}

variable "datadog_apmEnabled" {
  default     = "true"
  type        = string
  description = "Datadog enable trace agent"
}

variable "datadog_asm" {
  default     = "false"
  type        = string
  description = "Datadog Enable Application Security Management"
}

variable "datadog_securityAgent" {
  default     = "false"
  type        = string
  description = "Datadog Enable Cloud Security Posture Management"
}

variable "datadog_clusterCkeckReplicas" {
  default     = "2"
  type        = string
  description = "Datadog cluster checks replicas"
}


