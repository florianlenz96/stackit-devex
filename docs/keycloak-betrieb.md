# Keycloak selbst betreiben – was dazugehört

Im Diagramm ist Keycloak eine Box. Im Betrieb ist es ein eigenes Produkt. Diese Liste ist der Vergleichsmaßstab zu einem gemanagten Identity-Dienst (z. B. Microsoft Entra External ID).

| Thema | In dieser Demo | Für Produktion |
|---|---|---|
| Deployment | Deployment mit offiziellem Image, `start --import-realm` | Keycloak Operator oder Helm-Chart, optimiertes eigenes Image (`kc.sh build`) |
| Hochverfügbarkeit | 1 Replika | ≥ 2 Replikas, Clustering über jdbc-ping, PodDisruptionBudget |
| Datenbank | PostgreSQL Flex (gemanagt), eigene DB | Replika-Flavor, Backup-Restore regelmäßig testen |
| Updates | Tag `26.4` gepinnt | Release Notes beobachten, Staging-Upgrade vor Prod, Migrationen sind nicht rückwärtskompatibel |
| Secrets | Admin-/DB-Passwörter aus Secrets Manager via ESO | Bootstrap-Admin nach dem Start deaktivieren, Rotation |
| Angriffsfläche | `/auth/admin` öffentlich | Admin-Konsole nur intern (Traefik-Middleware, separater Hostname) |
| Monitoring | Health-Endpunkte, Metrics aktiviert | Scrape-Config für Metriken, Alerts auf Login-Fehlerraten |
| E-Mail | keine | SMTP für Passwort-Reset und Verifizierung (z. B. STACKIT MailOut, Beta) |
| Konfiguration als Code | Realm-JSON beim ersten Start | keycloak-config-cli oder Terraform-Provider für Keycloak |

**Faustregel für die Folie:** Ein gemanagter IdP ist Konfiguration. Ein selbst betriebener IdP ist Konfiguration plus Betrieb plus Verantwortung für den sicherheitskritischsten Dienst der Anwendung.
