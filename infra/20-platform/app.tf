# --- Namespace der Anwendung ---
resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.namespace
    labels = {
      # Pod Security Standards: "baseline" erzwingen, Verstöße gegen "restricted" melden.
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/warn"    = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
    }
  }
}

# Nicht-geheime Infrastrukturwerte, die Terraform kennt, die App aber braucht.
resource "kubernetes_config_map_v1" "infra" {
  metadata {
    name      = "askit-infra"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  data = {
    PGHOST      = local.cloud.postgres.host
    PGPORT      = tostring(local.cloud.postgres.port)
    S3_ENDPOINT = local.cloud.object_storage.endpoint
    S3_REGION   = local.cloud.object_storage.region
    S3_BUCKET   = local.cloud.object_storage.bucket
    AI_MODEL    = var.ai_model
  }
}

# --- Secrets in den STACKIT Secrets Manager schreiben (ESO holt sie ins Cluster) ---
locals {
  sm_mount = local.cloud.secrets_manager.instance_id
}

resource "random_password" "keycloak_admin" {
  length  = 24
  special = false
}

resource "random_password" "speaker" {
  length  = 20
  special = false
}

resource "vault_kv_secret_v2" "app_db" {
  mount               = local.sm_mount
  name                = "askit/app-db"
  delete_all_versions = true
  data_json = jsonencode({
    PGDATABASE = local.cloud.postgres.app.database
    PGUSER     = local.cloud.postgres.app.username
    PGPASSWORD = local.cloud.postgres.app.password
  })
}

resource "vault_kv_secret_v2" "keycloak_db" {
  mount               = local.sm_mount
  name                = "askit/keycloak-db"
  delete_all_versions = true
  data_json = jsonencode({
    KC_DB_URL      = "jdbc:postgresql://${local.cloud.postgres.host}:${local.cloud.postgres.port}/${local.cloud.postgres.keycloak.database}?sslmode=require"
    KC_DB_USERNAME = local.cloud.postgres.keycloak.username
    KC_DB_PASSWORD = local.cloud.postgres.keycloak.password
  })
}

resource "vault_kv_secret_v2" "keycloak_admin" {
  mount               = local.sm_mount
  name                = "askit/keycloak-admin"
  delete_all_versions = true
  data_json = jsonencode({
    KC_BOOTSTRAP_ADMIN_USERNAME = "admin"
    KC_BOOTSTRAP_ADMIN_PASSWORD = random_password.keycloak_admin.result
    # Wird beim Realm-Import in den User "speaker" (Rolle speaker) eingesetzt.
    SPEAKER_PASSWORD = random_password.speaker.result
  })
}

resource "vault_kv_secret_v2" "object_storage" {
  mount               = local.sm_mount
  name                = "askit/object-storage"
  delete_all_versions = true
  data_json = jsonencode({
    S3_ACCESS_KEY_ID     = local.cloud.object_storage.access_key
    S3_SECRET_ACCESS_KEY = local.cloud.object_storage.secret_access_key
  })
}

resource "vault_kv_secret_v2" "ai" {
  mount               = local.sm_mount
  name                = "askit/ai"
  delete_all_versions = true
  data_json           = jsonencode({ AI_API_KEY = local.cloud.ai_token })
}

# --- CI-Zugang: ServiceAccount, der nur im App-Namespace deployen darf ---
resource "kubernetes_service_account_v1" "deployer" {
  metadata {
    name      = "forgejo-deployer"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
}

resource "kubernetes_role_v1" "deployer" {
  metadata {
    name      = "deployer"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  rule {
    api_groups = ["", "apps", "networking.k8s.io", "external-secrets.io", "policy"]
    resources = [
      "deployments", "services", "configmaps", "ingresses", "externalsecrets",
      "poddisruptionbudgets", "pods", "pods/log", "replicasets", "events",
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"] # lesen ja (rollout), schreiben nein – Secrets kommen aus ESO
  }
}

resource "kubernetes_role_binding_v1" "deployer" {
  metadata {
    name      = "deployer"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployer.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.deployer.metadata[0].name
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
}

# Langlebiges Token für die Pipeline. Besser wäre Workload Identity – für die Demo reicht das.
resource "kubernetes_secret_v1" "deployer_token" {
  metadata {
    name      = "forgejo-deployer-token"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.deployer.metadata[0].name
    }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

# Pull-Zugang zur Container Registry. Der Robot Account selbst lässt sich nicht per Terraform anlegen.
resource "vault_kv_secret_v2" "registry" {
  mount               = local.sm_mount
  name                = "askit/registry"
  delete_all_versions = true
  data_json = jsonencode({
    username = var.registry_robot.username
    password = var.registry_robot.password
  })
}
