# --- Observability: Metriken, Logs, Traces (Grafana inklusive) ---
resource "stackit_observability_instance" "main" {
  project_id                             = var.project_id
  name                                   = "${var.name}-obs"
  plan_name                              = var.observability_plan
  logs_retention_days                    = 30
  traces_retention_days                  = 30
  metrics_retention_days                 = 90
  metrics_retention_days_5m_downsampling = 90
  metrics_retention_days_1h_downsampling = 90
}

# --- DNS: kostenlose Subdomain unter runs.onstackit.cloud, keine Domain-Delegation nötig ---
resource "stackit_dns_zone" "main" {
  project_id    = var.project_id
  name          = "${var.name}-zone"
  dns_name      = "${var.dns_subdomain}.runs.onstackit.cloud"
  contact_email = var.dns_contact_email
  type          = "primary"
}

# --- Kubernetes: STACKIT Kubernetes Engine (SKE) ---
resource "stackit_ske_cluster" "main" {
  project_id             = var.project_id
  name                   = var.name
  kubernetes_version_min = var.ske_kubernetes_version_min

  node_pools = [
    {
      name               = "default"
      machine_type       = var.ske_machine_type
      os_name            = "flatcar"
      minimum            = var.ske_nodes_min
      maximum            = var.ske_nodes_max
      availability_zones = ["eu01-1", "eu01-2"]
      volume_type        = "storage_premium_perf1"
      volume_size        = 40
    }
  ]

  maintenance = {
    enable_kubernetes_version_updates    = true
    enable_machine_image_version_updates = true
    start                                = "01:00:00Z"
    end                                  = "03:00:00Z"
  }

  extensions = {
    # Gemanagtes ExternalDNS: Records aus Ingress-Hosts landen automatisch in der STACKIT-Zone.
    dns = {
      enabled = true
      zones   = [stackit_dns_zone.main.dns_name]
    }
    # Cluster-Metriken und -Logs gehen an die Observability-Instanz.
    observability = {
      enabled     = true
      instance_id = stackit_observability_instance.main.instance_id
    }
    # Hinweis: extensions.application_load_balancer ist (Stand 09/2026) Private Preview.
    # Deshalb Traefik im Cluster + automatisch erzeugter STACKIT Network Load Balancer.
  }
}

# Kurzlebige Admin-Kubeconfig für Terraform (Stack 20-platform). Wird bei jedem Apply erneuert.
resource "stackit_ske_kubeconfig" "admin" {
  project_id     = var.project_id
  cluster_name   = stackit_ske_cluster.main.name
  refresh        = true
  expiration     = 7200
  refresh_before = 3600
}
