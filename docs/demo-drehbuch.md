# Demo-Drehbuch (ca. 25 Minuten Live-Anteil)

Grundregel: **Nichts Langsames live starten, was nicht vorher schon einmal gelaufen ist.** SKE und PostgreSQL Flex brauchen zusammen gut 15–25 Minuten. Die Infrastruktur steht deshalb vor dem Vortrag. Live gezeigt werden Code, Plan, Pipeline und die laufende App.

## Vorbereitung am Vortag

- [ ] Beide Terraform-Stacks angewendet, App erreichbar, TLS-Zertifikat gültig
- [ ] `terraform plan` in beiden Stacks zeigt „No changes“ (sonst Überraschungen live)
- [ ] Browser-Tabs: Portal (Projektübersicht), STACKIT Git (Actions-Tab), Grafana, App, Keycloak-Admin
- [ ] Terminal mit großer Schrift, `kubectl`-Kontext auf `askit`
- [ ] QR-Code zur App-URL auf einer Folie
- [ ] Kleine, sichtbare Änderung vorbereitet (z. B. Button-Text im Frontend) auf einem Branch
- [ ] Fallback: Screenshots oder Aufzeichnung jedes Akts, falls WLAN oder Pipeline streiken

## Akt 1: Infrastruktur als Code (ca. 7 min)

1. `infra/10-cloud/cluster.tf` zeigen: SKE mit DNS- und Observability-Extension. Den Kommentar zur ALB-Extension (Private Preview) ansprechen.
2. `services.tf`: PostgreSQL-ACL aus `egress_address_ranges`, Flavor per Data Source, AI-Token als einzige Ressource für KI.
3. Live: `terraform plan` → „No changes“. Dann eine harmlose Änderung (z. B. `retention_days = 40`) und `plan` zeigen: In-place-Update.
4. `infra/20-platform/platform.tf`: „Das hier gibt es bei Azure Container Apps nicht zu schreiben.“ Traefik, cert-manager und ESO benennen.
5. Überleitung: Was **nicht** in Terraform ging (Registry-Robot, Runner). Kurz das Portal zeigen.

## Akt 2: Code-Änderung bis Produktion (ca. 8 min)

1. Kleine Änderung im Frontend committen und nach `main` pushen.
2. STACKIT Git → Actions: `ci` und `deploy` laufen an. Während des Builds `deploy.yaml` erklären: `docker login` mit Robot Account, `kustomize edit set image`, Rollout, Smoke-Test.
3. Unterschiede zu GitHub Actions ansprechen: `.forgejo/workflows`, Action-URLs, Runner-Labels.
4. `kubectl -n askit get pods -w` zeigt das Rolling Update.

## Akt 3: Die App im Einsatz (ca. 7 min)

1. QR-Code-Folie: Publikum registriert sich (Keycloak-Selbstregistrierung) und stellt Fragen.
2. Screenshot-Upload zeigen → landet im privaten Bucket, Anzeige per Presigned URL.
3. Als `speaker` anmelden → „Offene Fragen zusammenfassen“ → AI Model Serving antwortet.
4. Grafana: Cluster-Metriken und Logs (`{namespace="askit"}`), kurz die JSON-Logs des Backends zeigen.

## Akt 4: Aufräumen und ehrliche Bilanz (ca. 3 min)

- Zeigen, wie viele Dateien für „eine kleine App“ nötig waren: `find infra k8s .forgejo -type f | wc -l`
- Überleitung zur Bewertungsfolie (Reifegrad-Ampel)

## Wenn etwas schiefgeht

| Symptom | Wahrscheinliche Ursache | Schnellcheck |
|---|---|---|
| Pods `ImagePullBackOff` | Pull-Robot fehlt oder abgelaufen | `kubectl -n askit get externalsecret registry` |
| Backend `CrashLoopBackOff` mit DB-Timeout | ACL: Egress-IP nicht freigegeben | `terraform -chdir=infra/10-cloud output ske_egress_ranges` |
| ExternalSecret `SecretSyncedError` | Secrets-Manager-ACL oder Reader-Passwort | `kubectl describe clustersecretstore stackit-secrets-manager` |
| Kein Zertifikat | DNS-Record fehlt, HTTP-01 schlägt fehl | `kubectl -n askit get certificate,challenge` |
| Login-Schleife | `KC_HOSTNAME` oder `APP_HOST` stimmen nicht | Keycloak-Logs, Realm-Redirect-URIs |
