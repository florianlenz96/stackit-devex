import express from 'express';
import client from 'prom-client';
import { httpError } from './auth.js';
import { ALLOWED_TYPES, MAX_UPLOAD_BYTES } from './storage.js';
import { log } from './log.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createApp({ pool, auth, storage, ai }) {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', true);

  // --- Metriken (Prometheus-Format, z. B. für STACKIT Observability) ---
  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });
  const httpDuration = new client.Histogram({
    name: 'askit_http_request_duration_seconds',
    help: 'Dauer der HTTP-Requests',
    labelNames: ['method', 'route', 'status'],
    buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
    registers: [registry],
  });
  const questionsCreated = new client.Counter({
    name: 'askit_questions_created_total',
    help: 'Anzahl gestellter Fragen',
    registers: [registry],
  });

  app.use((req, res, next) => {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      end({ method: req.method, route: req.route?.path ?? 'unmatched', status: res.statusCode });
    });
    next();
  });

  // --- Betrieb ---
  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));
  app.get('/readyz', async (_req, res) => {
    try {
      await pool.query('SELECT 1');
      res.json({ status: 'ready' });
    } catch (err) {
      res.status(503).json({ status: 'db unavailable', error: err.message });
    }
  });
  app.get('/metrics', async (_req, res) => {
    res.set('content-type', registry.contentType);
    res.send(await registry.metrics());
  });

  // --- API ---
  const api = express.Router();
  api.use(auth.identify);

  api.get('/config', (req, res) => {
    res.json({
      features: { attachments: Boolean(storage), aiSummary: Boolean(ai) },
      user: req.user,
    });
  });

  api.get('/questions', async (req, res) => {
    const { rows } = await pool.query(
      `SELECT q.id, q.text, q.author_name, q.attachment_key, q.answered, q.created_at,
              count(v.user_sub)::int AS votes,
              coalesce(bool_or(v.user_sub = $1), false) AS has_voted
         FROM questions q
         LEFT JOIN votes v ON v.question_id = q.id
        GROUP BY q.id
        ORDER BY q.answered ASC, votes DESC, q.created_at ASC
        LIMIT 200`,
      [req.user?.sub ?? null],
    );

    const questions = await Promise.all(
      rows.map(async (row) => ({
        id: row.id,
        text: row.text,
        author: row.author_name,
        answered: row.answered,
        createdAt: row.created_at,
        votes: row.votes,
        hasVoted: row.has_voted,
        attachmentUrl:
          row.attachment_key && storage ? await storage.signedGetUrl(row.attachment_key) : null,
      })),
    );
    res.json({ questions });
  });

  api.post('/questions', auth.requireUser, express.json({ limit: '16kb' }), async (req, res) => {
    const text = String(req.body?.text ?? '').trim();
    const attachmentKey = req.body?.attachmentKey ?? null;

    if (text.length < 3 || text.length > 500) {
      throw httpError(400, 'Die Frage braucht zwischen 3 und 500 Zeichen');
    }
    if (attachmentKey !== null && !/^attachments\/[0-9a-f-]{36}\.(png|jpg|webp)$/.test(attachmentKey)) {
      throw httpError(400, 'Ungültiger Anhang');
    }

    const { rows } = await pool.query(
      `INSERT INTO questions (text, author_sub, author_name, attachment_key)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [text, req.user.sub, req.user.name, attachmentKey],
    );
    questionsCreated.inc();
    log.info('question created', { id: rows[0].id });
    res.status(201).json({ id: rows[0].id });
  });

  api.post('/questions/:id/vote', auth.requireUser, async (req, res) => {
    if (!UUID.test(req.params.id)) throw httpError(404, 'Frage nicht gefunden');
    const removed = await pool.query('DELETE FROM votes WHERE question_id = $1 AND user_sub = $2', [
      req.params.id,
      req.user.sub,
    ]);
    if (removed.rowCount === 0) {
      const inserted = await pool.query(
        `INSERT INTO votes (question_id, user_sub)
         SELECT id, $2 FROM questions WHERE id = $1
         ON CONFLICT DO NOTHING`,
        [req.params.id, req.user.sub],
      );
      if (inserted.rowCount === 0) throw httpError(404, 'Frage nicht gefunden');
    }
    res.json({ voted: removed.rowCount === 0 });
  });

  api.post('/questions/:id/answered', auth.requireSpeaker, async (req, res) => {
    if (!UUID.test(req.params.id)) throw httpError(404, 'Frage nicht gefunden');
    const { rowCount } = await pool.query(
      'UPDATE questions SET answered = NOT answered WHERE id = $1',
      [req.params.id],
    );
    if (rowCount === 0) throw httpError(404, 'Frage nicht gefunden');
    res.json({ ok: true });
  });

  // Upload läuft über das Backend: kein Bucket-CORS nötig, Typ und Größe werden serverseitig geprüft.
  api.post(
    '/uploads',
    auth.requireUser,
    express.raw({ type: Object.keys(ALLOWED_TYPES), limit: MAX_UPLOAD_BYTES }),
    async (req, res) => {
      if (!storage) throw httpError(501, 'Anhänge sind nicht konfiguriert');
      if (!ALLOWED_TYPES[req.get('content-type')] || !Buffer.isBuffer(req.body) || req.body.length === 0) {
        throw httpError(415, 'Erlaubt sind PNG, JPEG und WebP bis 5 MB');
      }
      const key = await storage.putImage(req.body, req.get('content-type'));
      res.status(201).json({ key });
    },
  );

  api.post('/summary', auth.requireSpeaker, async (_req, res) => {
    if (!ai) throw httpError(501, 'KI-Zusammenfassung ist nicht konfiguriert');
    const { rows } = await pool.query(
      `SELECT q.text, count(v.user_sub)::int AS votes
         FROM questions q LEFT JOIN votes v ON v.question_id = q.id
        WHERE NOT q.answered
        GROUP BY q.id ORDER BY votes DESC LIMIT 50`,
    );
    if (rows.length === 0) return res.json({ summary: 'Noch keine offenen Fragen.', model: ai.model });
    const summary = await ai.summarize(rows);
    res.json({ summary, model: ai.model });
  });

  app.use('/api', api);

  // --- Fehlerbehandlung ---
  app.use((_req, _res, next) => next(httpError(404, 'Nicht gefunden')));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    const status = err.status ?? err.statusCode ?? 500;
    if (status >= 500) log.error('request failed', { path: req.path, error: err.message });
    res.status(status).json({ error: status >= 500 ? 'Interner Fehler' : err.message });
  });

  return app;
}
