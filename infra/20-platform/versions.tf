terraform {
  required_version = ">= 1.9"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    key                         = "askit/20-platform.tfstate"
    region                      = "eu01"
    endpoints                   = { s3 = "https://object.storage.eu01.onstackit.cloud" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }
}

# Ergebnisse aus Stack 10-cloud. Zwei Stacks, weil Kubernetes-/Vault-Provider erst
# konfiguriert werden können, wenn Cluster und Secrets Manager existieren.
data "terraform_remote_state" "cloud" {
  backend = "s3"
  config = {
    key                         = "askit/10-cloud.tfstate"
    bucket                      = var.state_bucket
    access_key                  = var.state_access_key
    secret_key                  = var.state_secret_key
    region                      = "eu01"
    endpoints                   = { s3 = "https://object.storage.eu01.onstackit.cloud" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    skip_metadata_api_check     = true
  }
}

locals {
  cloud      = data.terraform_remote_state.cloud.outputs
  kubeconfig = yamldecode(local.cloud.kubeconfig)

  k8s = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  }
}

provider "kubernetes" {
  host                   = local.k8s.host
  cluster_ca_certificate = local.k8s.cluster_ca_certificate
  client_certificate     = local.k8s.client_certificate
  client_key             = local.k8s.client_key
}

provider "helm" {
  kubernetes = {
    host                   = local.k8s.host
    cluster_ca_certificate = local.k8s.cluster_ca_certificate
    client_certificate     = local.k8s.client_certificate
    client_key             = local.k8s.client_key
  }
}

# STACKIT Secrets Manager spricht die Vault-API.
provider "vault" {
  address          = local.cloud.secrets_manager.address
  skip_child_token = true
  auth_login_userpass {
    username = local.cloud.secrets_manager.writer.username
    password = local.cloud.secrets_manager.writer.password
  }
}
