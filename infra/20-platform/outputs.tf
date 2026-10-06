output "ci_kubeconfig" {
  description = "Kubeconfig für die Forgejo-Pipeline (als Secret KUBECONFIG_B64 hinterlegen, base64-kodiert)"
  sensitive   = true
  value = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "askit"
    clusters = [{
      name = "askit"
      cluster = {
        server                     = local.k8s.host
        certificate-authority-data = base64encode(local.k8s.cluster_ca_certificate)
      }
    }]
    users = [{
      name = "forgejo-deployer"
      user = { token = kubernetes_secret_v1.deployer_token.data["token"] }
    }]
    contexts = [{
      name    = "askit"
      context = { cluster = "askit", user = "forgejo-deployer", namespace = var.namespace }
    }]
  })
}

output "keycloak_admin_password" {
  sensitive = true
  value     = random_password.keycloak_admin.result
}

output "speaker_password" {
  description = "Login für den Keycloak-User 'speaker'"
  sensitive   = true
  value       = random_password.speaker.result
}

output "app_url" {
  value = "https://${local.cloud.app_host}"
}
