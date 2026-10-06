output "app_host" {
  description = "Öffentlicher Hostname der Anwendung"
  value       = "app.${stackit_dns_zone.main.dns_name}"
}

output "dns_zone" {
  value = stackit_dns_zone.main.dns_name
}

output "ske_cluster_name" {
  value = stackit_ske_cluster.main.name
}

output "ske_egress_ranges" {
  description = "Egress-IPs des Clusters (für Firewall-Freigaben)"
  value       = stackit_ske_cluster.main.egress_address_ranges
}

output "kubeconfig" {
  description = "Kurzlebige Admin-Kubeconfig (für Stack 20-platform)"
  value       = stackit_ske_kubeconfig.admin.kube_config
  sensitive   = true
}

output "postgres" {
  description = "Verbindungsdaten für App und Keycloak"
  sensitive   = true
  value = {
    host = stackit_postgresflex_instance.main.connection_info.write.host
    port = stackit_postgresflex_instance.main.connection_info.write.port
    app = {
      database = stackit_postgresflex_database.app.name
      username = stackit_postgresflex_user.app.username
      password = stackit_postgresflex_user.app.password
    }
    keycloak = {
      database = stackit_postgresflex_database.keycloak.name
      username = stackit_postgresflex_user.keycloak.username
      password = stackit_postgresflex_user.keycloak.password
    }
  }
}

output "object_storage" {
  sensitive = true
  value = {
    endpoint          = "https://object.storage.${var.region}.onstackit.cloud"
    region            = var.region
    bucket            = stackit_objectstorage_bucket.attachments.name
    access_key        = stackit_objectstorage_credential.app.access_key
    secret_access_key = stackit_objectstorage_credential.app.secret_access_key
  }
}

output "secrets_manager" {
  sensitive = true
  value = {
    address     = "https://prod.sm.${var.region}.stackit.cloud"
    instance_id = stackit_secretsmanager_instance.main.instance_id
    writer = {
      username = stackit_secretsmanager_user.terraform.username
      password = stackit_secretsmanager_user.terraform.password
    }
    reader = {
      username = stackit_secretsmanager_user.cluster.username
      password = stackit_secretsmanager_user.cluster.password
    }
  }
}

output "ai_token" {
  value     = stackit_modelserving_token.app.token
  sensitive = true
}

output "grafana_url" {
  value = stackit_observability_instance.main.grafana_url
}

output "grafana_initial_admin" {
  sensitive = true
  value = {
    user     = stackit_observability_instance.main.grafana_initial_admin_user
    password = stackit_observability_instance.main.grafana_initial_admin_password
  }
}

output "git_url" {
  value = var.enable_git ? stackit_git.main[0].url : null
}
