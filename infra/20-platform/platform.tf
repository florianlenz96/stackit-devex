# Alles in dieser Datei ist "Plattform-Arbeit", die auf Azure Container Apps entfallen würde:
# Ingress-Controller, Zertifikate und Secret-Synchronisation betreiben wir hier selbst.

# --- Ingress: Traefik. Der Service vom Typ LoadBalancer erzeugt automatisch einen STACKIT NLB. ---
# (ingress-nginx wurde von der Kubernetes-Community eingestellt, daher Traefik.)
resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = "traefik"
  create_namespace = true
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.chart_versions.traefik

  values = [yamlencode({
    ingressClass = { enabled = true, isDefaultClass = true }
    service = {
      type = "LoadBalancer"
      spec = { externalTrafficPolicy = "Local" }
    }
    ports = {
      web = {
        http = {
          redirections = {
            entryPoint = { to = "websecure", scheme = "https", permanent = true }
          }
        }
      }
    }
    # Schreibt die NLB-IP in den Ingress-Status – daraus erzeugt das SKE-ExternalDNS die A-Records.
    providers = { kubernetesIngress = { publishedService = { enabled = true } } }
  })]
}

# --- TLS: cert-manager + Let's Encrypt ---
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_versions.cert_manager

  values = [yamlencode({ crds = { enabled = true } })]
}

# --- Secrets: External Secrets Operator synchronisiert STACKIT Secrets Manager -> K8s Secrets ---
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_versions.external_secrets
}

# Passwort des Lese-Users für den Secrets Manager (das einzige Secret, das Terraform direkt ins Cluster legt)
resource "kubernetes_secret_v1" "secrets_manager_reader" {
  metadata {
    name      = "stackit-secrets-manager"
    namespace = helm_release.external_secrets.namespace
  }
  data = {
    password = local.cloud.secrets_manager.reader.password
  }
}

# ClusterIssuer und ClusterSecretStore sind CRDs. Als lokales Mini-Chart installiert,
# damit der erste Plan nicht an noch fehlenden CRDs scheitert.
resource "helm_release" "platform_config" {
  name      = "platform-config"
  namespace = "kube-system"
  chart     = "${path.module}/charts/platform-config"

  values = [yamlencode({
    letsencryptEmail = var.letsencrypt_email
    secretsManager = {
      address    = local.cloud.secrets_manager.address
      instanceId = local.cloud.secrets_manager.instance_id
      username   = local.cloud.secrets_manager.reader.username
      passwordSecret = {
        name      = kubernetes_secret_v1.secrets_manager_reader.metadata[0].name
        namespace = kubernetes_secret_v1.secrets_manager_reader.metadata[0].namespace
      }
    }
  })]

  depends_on = [helm_release.cert_manager, helm_release.external_secrets, helm_release.traefik]
}
