variable "state_bucket" {
  description = "Bucket mit dem Terraform-State (gleicher wie in backend.hcl)"
  type        = string
}

variable "state_access_key" {
  type      = string
  sensitive = true
}

variable "state_secret_key" {
  type      = string
  sensitive = true
}

variable "letsencrypt_email" {
  description = "E-Mail für Let's-Encrypt-Benachrichtigungen"
  type        = string
}

variable "ai_model" {
  description = "Chat-Modell aus STACKIT AI Model Serving (Liste: Doku 'Available shared models')"
  type        = string
  default     = "Qwen/Qwen3.8-27B"
}

variable "namespace" {
  type    = string
  default = "askit"
}

# Chart-Versionen bewusst pinnen – in der Demo einmal mit `helm search repo` prüfen.
variable "chart_versions" {
  type = object({
    traefik          = optional(string)
    cert_manager     = optional(string)
    external_secrets = optional(string)
  })
  default = {}
}

variable "registry_robot" {
  description = "Robot Account der STACKIT Container Registry (manuell im Portal erzeugt) – für imagePullSecrets"
  type = object({
    username = string
    password = string
  })
  sensitive = true
}
