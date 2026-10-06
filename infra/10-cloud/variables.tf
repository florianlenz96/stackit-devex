variable "project_id" {
  description = "ID des STACKIT-Projekts"
  type        = string
}

variable "region" {
  description = "STACKIT-Region"
  type        = string
  default     = "eu01"
}

variable "name" {
  description = "Präfix für alle Ressourcen"
  type        = string
  default     = "askit"
}

variable "dns_subdomain" {
  description = "Kostenlose STACKIT-Subdomain, z. B. \"askit-demo\" ergibt askit-demo.runs.onstackit.cloud"
  type        = string
}

variable "dns_contact_email" {
  description = "Kontakt-E-Mail für die DNS-Zone"
  type        = string
}

variable "admin_cidrs" {
  description = "Zusätzliche IP-Bereiche mit Zugriff auf DB und Secrets Manager (z. B. dein Laptop oder die CI-Runner)"
  type        = list(string)
  default     = []
}

variable "ske_kubernetes_version_min" {
  description = "Minimale Kubernetes-Version. Leer lassen = neueste von SKE unterstützte"
  type        = string
  default     = null
}

variable "ske_machine_type" {
  description = "Maschinentyp der Worker Nodes"
  type        = string
  default     = "g2i.2"
}

variable "ske_nodes_min" {
  type    = number
  default = 2
}

variable "ske_nodes_max" {
  type    = number
  default = 3
}

variable "postgres_cpu" {
  description = "vCPUs der PostgreSQL-Flex-Instanz (Flavor wird per Data Source gesucht)"
  type        = number
  default     = 2
}

variable "postgres_memory" {
  description = "RAM in GiB der PostgreSQL-Flex-Instanz"
  type        = number
  default     = 4
}

variable "postgres_version" {
  type    = string
  default = "17"
}

variable "observability_plan" {
  description = "Plan der Observability-Instanz"
  type        = string
  default     = "Observability-Starter-EU01"
}

variable "enable_git" {
  description = "STACKIT Git per Terraform anlegen (Beta-Ressource). false, wenn die Instanz schon existiert"
  type        = bool
  default     = true
}
