# askit – Fragen an den Speaker, deployt auf STACKIT

Beispielanwendung für den Vortrag **„STACKIT im Praxistest: Deployment, Developer Experience und Architektur-Fit“**.

Das Publikum stellt per Handy Fragen zum Vortrag und stimmt ab. Der Speaker markiert Fragen als beantwortet und lässt die offenen Fragen per KI zusammenfassen. Die App ist bewusst klein, nutzt aber jeden Baustein, den eine typische Business-Anwendung braucht.

```
Browser ─► STACKIT DNS ─► NLB ─► Traefik (SKE) ─┬─► frontend  (nginx, statisches JS)
                                                ├─► backend   (Node.js) ─┬─► PostgreSQL Flex
                                                │                         ├─► Object Storage
                                                │                         └─► AI Model Serving
                                                └─► keycloak  (/auth) ────► PostgreSQL Flex
Secrets: Terraform ─► STACKIT Secrets Manager ─► External Secrets Operator ─► K8s Secrets
CI/CD:   STACKIT Git (Forgejo) ─► Container Registry (Harbor) ─► SKE
```

## Was wo liegt

| Pfad | Inhalt |
|---|---|
| `app/backend` | Express-API: Fragen, Votes, Uploads, KI-Zusammenfassung, `/healthz`, `/readyz`, `/metrics` |
| `app/frontend` | Vite + keycloak-js, Laufzeit-Konfiguration über `config.js` |
| `infra/10-cloud` | STACKIT-Ressourcen: SKE, PostgreSQL Flex, Object Storage, DNS, Secrets Manager, Observability, Git, AI-Token |
| `infra/20-platform` | Im Cluster: Traefik, cert-manager, External Secrets, Secrets befüllen, CI-ServiceAccount |
| `k8s/` | Kustomize-Manifeste für Frontend, Backend, Keycloak, Ingress |
| `.forgejo/workflows` | `ci` (Tests), `deploy` (Build, Push, Rollout), `infra` (Terraform) |
| `docs/` | Demo-Drehbuch, Keycloak-Betrieb, DX-Logbuch für die Generalprobe |

## Voraussetzungen

- STACKIT-Projekt und ein Service Account mit Projektrechten (Key als JSON herunterladen)
- Lokal: Terraform ≥ 1.9, `kubectl`, `stackit` CLI, `jq`
- **Manuell im Portal** (gibt es nicht als Terraform-Ressource):
  1. Container Registry: Projekt `askit` anlegen, Robot Account mit `push`/`pull` erzeugen. Das Token wird nur einmal angezeigt.
  2. STACKIT Git: Managed Runner aktivieren (bzw. eigenen Runner registrieren) und das Runner-Label in den Workflows prüfen.
  3. Einen zweiten Robot Account nur mit `pull` für den Cluster anlegen und in `infra/20-platform/terraform.tfvars` eintragen. Daraus wird das `imagePullSecret`.

## Aufbau Schritt für Schritt

```bash
# 0. Anmelden
export STACKIT_SERVICE_ACCOUNT_KEY_PATH=~/.stackit/askit-sa-key.json
export STACKIT_PROJECT_ID=<projekt-id>

# 1. State-Bucket (einmalig)
cd scripts && ./bootstrap-state.sh && cd ..

# 2. Cloud-Ressourcen (~15–25 min, SKE und PostgreSQL dauern am längsten)
cd infra/10-cloud
cp terraform.tfvars.example terraform.tfvars   # anpassen
terraform init -backend-config=backend.hcl
terraform apply

# 3. Plattform im Cluster
cd ../20-platform
cp terraform.tfvars.example terraform.tfvars   # State-Zugang + E-Mail
terraform init -backend-config=backend.hcl
terraform apply

# 4. Hostname eintragen und Pipeline-Secrets setzen
terraform -chdir=../10-cloud output -raw app_host      # -> k8s/overlays/demo/params.env
terraform output -raw ci_kubeconfig | base64 -w0       # -> Secret KUBECONFIG_B64 in Forgejo

# 5. Pushen – die Pipeline baut, pusht und deployt
git remote add stackit $(terraform -chdir=../10-cloud output -raw git_url)/<org>/askit.git
git push stackit main
```

Speaker-Login: User `speaker`, Passwort aus `terraform -chdir=infra/20-platform output -raw speaker_password`.

## Lokal entwickeln

```bash
docker compose up -d
cd app/backend  && cp .env.example .env && npm install && npm run dev
cd app/frontend && npm install && npm run dev      # http://localhost:5173
```

## Bekannte Einschränkungen (Stand September 2026, Provider 0.117)

- `stackit_git` ist eine Beta-Ressource (`enable_beta_resources = true`). Änderungen an ACL, Flavor oder Name erzwingen ein Neuerstellen.
- Die SKE-Erweiterung für den Application Load Balancer ist Private Preview. Daher Traefik plus automatisch erzeugter Network Load Balancer.
- Für die Container Registry gibt es keine Terraform-Ressource. Für Robot Accounts wäre der Harbor-Provider eine Option.
- Keycloak ist selbst betrieben. Was dafür zu tun ist: `docs/keycloak-betrieb.md`.
- `/auth/admin` ist öffentlich erreichbar. Für Produktion per Traefik-Middleware auf interne IPs beschränken.

## Kosten und Aufräumen

SKE-Nodes, PostgreSQL Flex und Observability laufen stündlich. Nach der Demo:

```bash
terraform -chdir=infra/20-platform destroy
terraform -chdir=infra/10-cloud destroy
```
