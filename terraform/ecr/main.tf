terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the private ECR Helm chart repositories."
  type        = string
}

variable "chart_names" {
  description = "ECR repository names. Must match the upstream Helm chart names used by helm push."
  type        = set(string)
  default = [
    "aws-load-balancer-controller",
    "secrets-store-csi-driver",
    "cluster-autoscaler",
    "datadog",
  ]
}

resource "aws_ecr_repository" "charts" {
  for_each             = var.chart_names
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

output "repository_urls" {
  description = "ECR repository URLs keyed by chart name."
  value       = { for name, repo in aws_ecr_repository.charts : name => repo.repository_url }
}
