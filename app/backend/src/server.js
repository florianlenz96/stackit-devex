import { loadConfig } from './config.js';
import { createPool, migrate } from './db.js';
import { createAuth } from './auth.js';
import { createStorage } from './storage.js';
import { createAi } from './ai.js';
import { createApp } from './app.js';
import { log } from './log.js';

const config = loadConfig();
const pool = createPool(config.db);

await migrate(pool);

const app = createApp({
  pool,
  auth: createAuth(config.oidc),
  storage: createStorage(config.s3),
  ai: createAi(config.ai),
});

const server = app.listen(config.port, () => {
  log.info('askit backend listening', {
    port: config.port,
    attachments: Boolean(config.s3),
    aiSummary: Boolean(config.ai),
  });
});

// Kubernetes schickt SIGTERM vor dem Beenden: laufende Requests sauber abschließen.
function shutdown(signal) {
  log.info('shutting down', { signal });
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
