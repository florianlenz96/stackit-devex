import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';
import { httpError } from '../src/auth.js';

// Fake-Auth: der Header "x-test-user" simuliert ein gültiges Token.
const fakeAuth = {
  identify(req, _res, next) {
    const who = req.get('x-test-user');
    req.user = who ? { sub: who, name: who, isSpeaker: who === 'speaker' } : null;
    next();
  },
  requireUser(req, _res, next) {
    next(req.user ? undefined : httpError(401, 'Bitte zuerst anmelden'));
  },
  requireSpeaker(req, _res, next) {
    if (!req.user) return next(httpError(401, 'Bitte zuerst anmelden'));
    next(req.user.isSpeaker ? undefined : httpError(403, 'Nur für die Speaker-Rolle'));
  },
};

function fakePool(handler = () => ({ rows: [], rowCount: 0 })) {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push({ sql, params });
      return handler(sql, params);
    },
  };
}

async function withServer(deps, fn) {
  const app = createApp({ auth: fakeAuth, storage: null, ai: null, ...deps });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

test('healthz antwortet ohne Datenbank', async () => {
  await withServer({ pool: fakePool() }, async (base) => {
    const res = await fetch(`${base}/healthz`);
    assert.equal(res.status, 200);
  });
});

test('Fragen lesen geht anonym', async () => {
  const pool = fakePool(() => ({
    rows: [{ id: '1', text: 'Wie teuer ist SKE?', author_name: 'Ada', votes: 3, has_voted: false }],
  }));
  await withServer({ pool }, async (base) => {
    const res = await fetch(`${base}/api/questions`);
    const body = await res.json();
    assert.equal(res.status, 200);
    assert.equal(body.questions[0].votes, 3);
    assert.equal(body.questions[0].attachmentUrl, null);
  });
});

test('Frage stellen verlangt Login', async () => {
  await withServer({ pool: fakePool() }, async (base) => {
    const res = await fetch(`${base}/api/questions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: 'Hallo?' }),
    });
    assert.equal(res.status, 401);
  });
});

test('zu kurze Fragen werden abgelehnt', async () => {
  await withServer({ pool: fakePool() }, async (base) => {
    const res = await fetch(`${base}/api/questions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-test-user': 'ada' },
      body: JSON.stringify({ text: 'a' }),
    });
    assert.equal(res.status, 400);
  });
});

test('Frage wird gespeichert', async () => {
  const pool = fakePool(() => ({ rows: [{ id: 'abc' }], rowCount: 1 }));
  await withServer({ pool }, async (base) => {
    const res = await fetch(`${base}/api/questions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-test-user': 'ada' },
      body: JSON.stringify({ text: 'Gibt es Serverless Container?' }),
    });
    assert.equal(res.status, 201);
    assert.deepEqual(pool.calls[0].params.slice(0, 3), ['Gibt es Serverless Container?', 'ada', 'ada']);
  });
});

test('als beantwortet markieren nur für Speaker', async () => {
  const id = '3f1c2a52-6f0e-4c3b-9a55-2d9d1b1c0a11';
  await withServer({ pool: fakePool(() => ({ rows: [], rowCount: 1 })) }, async (base) => {
    const asUser = await fetch(`${base}/api/questions/${id}/answered`, {
      method: 'POST',
      headers: { 'x-test-user': 'ada' },
    });
    assert.equal(asUser.status, 403);
    const asSpeaker = await fetch(`${base}/api/questions/${id}/answered`, {
      method: 'POST',
      headers: { 'x-test-user': 'speaker' },
    });
    assert.equal(asSpeaker.status, 200);
  });
});

test('Upload ohne Object Storage liefert 501', async () => {
  await withServer({ pool: fakePool() }, async (base) => {
    const res = await fetch(`${base}/api/uploads`, {
      method: 'POST',
      headers: { 'content-type': 'image/png', 'x-test-user': 'ada' },
      body: new Uint8Array([1, 2, 3]),
    });
    assert.equal(res.status, 501);
  });
});
