#!/bin/sh
# Laufzeit-Konfiguration statt Build-Zeit: dasselbe Image läuft in jeder Umgebung.
set -eu
cat > /usr/share/nginx/html/config.js <<CFG
window.ASKIT_CONFIG = {
  talkTitle: "${TALK_TITLE:-STACKIT im Praxistest}",
  keycloakRealm: "${KEYCLOAK_REALM:-askit}",
  keycloakClientId: "${KEYCLOAK_CLIENT_ID:-askit-frontend}"
};
CFG
