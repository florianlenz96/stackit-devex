locals {
  # Nur der Cluster (und optional Admins/CI) darf auf DB und Secrets Manager zugreifen.
  trusted_cidrs = concat(stackit_ske_cluster.main.egress_address_ranges, var.admin_cidrs)
}

# --- PostgreSQL Flex: eine Instanz, zwei Datenbanken (App und Keycloak) ---
data "stackit_postgresflex_flavors" "all" {
  project_id = var.project_id
}

resource "stackit_postgresflex_instance" "main" {
  project_id = var.project_id
  name       = "${var.name}-pg"
  version    = var.postgres_version
  flavor_id = one([
    for f in data.stackit_postgresflex_flavors.all.flavors : f.id
    if f.cpu == var.postgres_cpu && f.memory == var.postgres_memory && f.node_type == "Single"
  ])
  storage = {
    class = "premium-perf2-stackit"
    size  = 10
  }
  backup_schedule = "0 2 * * *"
  retention_days  = 32
  network = {
    acl = local.trusted_cidrs
  }
}

resource "stackit_postgresflex_user" "app" {
  project_id  = var.project_id
  instance_id = stackit_postgresflex_instance.main.instance_id
  username    = "askit"
  roles       = ["login"]
}

resource "stackit_postgresflex_user" "keycloak" {
  project_id  = var.project_id
  instance_id = stackit_postgresflex_instance.main.instance_id
  username    = "keycloak"
  roles       = ["login"]
}

resource "stackit_postgresflex_database" "app" {
  project_id  = var.project_id
  instance_id = stackit_postgresflex_instance.main.instance_id
  name        = "askit"
  owner       = stackit_postgresflex_user.app.username
}

resource "stackit_postgresflex_database" "keycloak" {
  project_id  = var.project_id
  instance_id = stackit_postgresflex_instance.main.instance_id
  name        = "keycloak"
  owner       = stackit_postgresflex_user.keycloak.username
}

# --- Object Storage: privater Bucket für Screenshots (und separat: der Terraform-State) ---
resource "stackit_objectstorage_bucket" "attachments" {
  project_id = var.project_id
  name       = "${var.name}-attachments-${var.dns_subdomain}"
}

resource "stackit_objectstorage_credentials_group" "app" {
  project_id = var.project_id
  name       = "${var.name}-app"
}

resource "time_rotating" "s3" {
  rotation_days = 80
}

resource "stackit_objectstorage_credential" "app" {
  project_id           = var.project_id
  credentials_group_id = stackit_objectstorage_credentials_group.app.credentials_group_id
  expiration_timestamp = timeadd(time_rotating.s3.id, "2160h") # 90 Tage
  rotate_when_changed = {
    rotation = time_rotating.s3.id
  }
}

# --- Secrets Manager (Vault-kompatibel) + ein Schreib-User für Terraform/ESO ---
resource "stackit_secretsmanager_instance" "main" {
  project_id = var.project_id
  name       = "${var.name}-secrets"
  acls       = local.trusted_cidrs
}

resource "stackit_secretsmanager_user" "terraform" {
  project_id    = var.project_id
  instance_id   = stackit_secretsmanager_instance.main.instance_id
  description   = "Terraform (Stack 20-platform) schreibt Secrets"
  write_enabled = true
}

resource "stackit_secretsmanager_user" "cluster" {
  project_id    = var.project_id
  instance_id   = stackit_secretsmanager_instance.main.instance_id
  description   = "External Secrets Operator im SKE-Cluster liest Secrets"
  write_enabled = false
}

# --- AI Model Serving: nur ein Token, die Modelle sind geteilte Instanzen ---
resource "time_rotating" "ai" {
  rotation_days = 80
}

resource "stackit_modelserving_token" "app" {
  project_id = var.project_id
  name       = "${var.name}-app"
  rotate_when_changed = {
    rotation = time_rotating.ai.id
  }
}

# --- STACKIT Git (Forgejo) – Beta-Ressource ---
resource "stackit_git" "main" {
  count      = var.enable_git ? 1 : 0
  project_id = var.project_id
  name       = var.name
}

# Nicht per Terraform verfügbar (Stand Provider 0.117):
#   - STACKIT Container Registry (Projekt + Robot Account) -> Portal, siehe README
#   - Managed Runner für STACKIT Git -> im Portal aktivieren
