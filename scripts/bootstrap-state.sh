#!/usr/bin/env bash
# Einmalig: Bucket für den Terraform-State im STACKIT Object Storage anlegen.
# Henne-Ei-Problem jeder IaC-Plattform – hier gelöst mit der STACKIT CLI.
#
# Voraussetzungen: stackit CLI + jq, angemeldet (stackit auth login),
#                  STACKIT_PROJECT_ID gesetzt, optional BUCKET (Default: askit-tfstate-<zufall>)
set -euo pipefail

: "${STACKIT_PROJECT_ID:?STACKIT_PROJECT_ID setzen}"
BUCKET="${BUCKET:-askit-tfstate-$(openssl rand -hex 3)}"
FLAGS=(--project-id "$STACKIT_PROJECT_ID" --assume-yes)

echo ">> Object Storage im Projekt aktivieren (idempotent)"
stackit object-storage enable "${FLAGS[@]}" || true

echo ">> Bucket $BUCKET anlegen"
stackit object-storage bucket create "$BUCKET" "${FLAGS[@]}"

echo ">> Credentials-Gruppe und Zugangsschlüssel für Terraform"
# JSON-Feldnamen je nach CLI-Version einmal mit --output-format json prüfen.
GROUP_ID=$(stackit object-storage credentials-group create --name terraform-state "${FLAGS[@]}" --output-format json \
  | jq -r '.credentialsGroup.credentialsGroupId')
CREDS=$(stackit object-storage credentials create --credentials-group-id "$GROUP_ID" "${FLAGS[@]}" --output-format json)

cat > backend.hcl <<HCL
bucket     = "$BUCKET"
access_key = "$(echo "$CREDS" | jq -r '.accessKey')"
secret_key = "$(echo "$CREDS" | jq -r '.secretAccessKey')"
HCL

cp backend.hcl ../infra/10-cloud/backend.hcl
mv backend.hcl ../infra/20-platform/backend.hcl
echo ">> Fertig. backend.hcl liegt in infra/10-cloud und infra/20-platform (nicht committen!)"
