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
