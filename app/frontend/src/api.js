import { accessToken } from './auth.js';

async function request(path, { method = 'GET', json, body, contentType } = {}) {
  const headers = {};
  const token = await accessToken();
  if (token) headers.authorization = `Bearer ${token}`;
  if (json !== undefined) headers['content-type'] = 'application/json';
  if (contentType) headers['content-type'] = contentType;

  const res = await fetch(`/api${path}`, {
    method,
    headers,
    body: json !== undefined ? JSON.stringify(json) : body,
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error ?? `Anfrage fehlgeschlagen (${res.status})`);
  return data;
}

export const api = {
  config: () => request('/config'),
  questions: () => request('/questions'),
  ask: (text, attachmentKey) => request('/questions', { method: 'POST', json: { text, attachmentKey } }),
  vote: (id) => request(`/questions/${id}/vote`, { method: 'POST' }),
  toggleAnswered: (id) => request(`/questions/${id}/answered`, { method: 'POST' }),
  upload: (file) => request('/uploads', { method: 'POST', body: file, contentType: file.type }),
  summarize: () => request('/summary', { method: 'POST' }),
};
