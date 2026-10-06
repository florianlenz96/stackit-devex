terraform {
  required_version = ">= 1.9"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = "~> 0.117"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # State liegt im STACKIT Object Storage (S3-kompatibel).
  # Henne-Ei-Problem: Den Bucket einmalig mit scripts/bootstrap-state.sh anlegen.
  backend "s3" {
    key = "askit/10-cloud.tfstate"
    # bucket, access_key, secret_key kommen aus backend.hcl (siehe backend.hcl.example)
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

# Authentifizierung über Service Account Key:
#   export STACKIT_SERVICE_ACCOUNT_KEY_PATH=~/.stackit/askit-sa-key.json
provider "stackit" {
  default_region = var.region

  # stackit_git ist (Stand Provider 0.117) noch eine Beta-Ressource.
  enable_beta_resources = true
}
