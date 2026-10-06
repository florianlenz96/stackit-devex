// Zentrale Konfiguration – alles kommt aus Umgebungsvariablen (12-Factor).
// In SKE werden die Werte aus ConfigMap + ExternalSecret (STACKIT Secrets Manager) gesetzt.

function optional(name, fallback = undefined) {
  const value = process.env[name];
  return value === undefined || value === '' ? fallback : value;
}

function required(name) {
  const value = optional(name);
  if (value === undefined) {
    throw new Error(`Umgebungsvariable ${name} fehlt`);
  }
  return value;
}

export function loadConfig() {
  const issuer = required('OIDC_ISSUER');

  const s3Enabled = Boolean(optional('S3_BUCKET') && optional('S3_ENDPOINT'));
  const aiEnabled = Boolean(optional('AI_API_KEY'));

  return {
    port: Number(optional('PORT', '8080')),
    db: {
      host: required('PGHOST'),
      port: Number(optional('PGPORT', '5432')),
      database: required('PGDATABASE'),
      user: required('PGUSER'),
      password: required('PGPASSWORD'),
      // "require": TLS ohne Zertifikatsprüfung, "verify": mit Prüfung, "disable": ohne TLS (nur lokal)
      sslMode: optional('DB_SSL', 'require'),
    },
    oidc: {
      issuer,
      clientId: optional('OIDC_CLIENT_ID', 'askit-frontend'),
      // Im Cluster kann der JWKS-Endpunkt intern erreicht werden, der Issuer bleibt öffentlich.
      jwksUrl: optional('OIDC_JWKS_URL', `${issuer}/protocol/openid-connect/certs`),
      speakerRole: optional('SPEAKER_ROLE', 'speaker'),
    },
    s3: s3Enabled
      ? {
          endpoint: required('S3_ENDPOINT'),
          region: optional('S3_REGION', 'eu01'),
          bucket: required('S3_BUCKET'),
          accessKeyId: required('S3_ACCESS_KEY_ID'),
          secretAccessKey: required('S3_SECRET_ACCESS_KEY'),
        }
      : null,
    ai: aiEnabled
      ? {
          // STACKIT AI Model Serving ist OpenAI-kompatibel.
          baseUrl: optional('AI_BASE_URL', 'https://api.openai-compat.model-serving.eu01.onstackit.cloud/v1'),
          apiKey: required('AI_API_KEY'),
          model: required('AI_MODEL'),
        }
      : null,
  };
}
