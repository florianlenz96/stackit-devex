import './style.css';
import { api } from './api.js';
import { displayName, initAuth, login, logout } from './auth.js';

const $ = (id) => document.getElementById(id);
const state = { authenticated: false, isSpeaker: false, features: {}, busy: new Set() };

if (window.ASKIT_CONFIG?.talkTitle) $('talk-title').textContent = window.ASKIT_CONFIG.talkTitle;

function renderSession() {
  const el = $('session');
  el.replaceChildren();
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'link';
  if (state.authenticated) {
    const name = document.createElement('span');
    name.textContent = displayName() + (state.isSpeaker ? ' (Speaker)' : '');
    button.textContent = 'Abmelden';
    button.addEventListener('click', logout);
    el.append(name, button);
  } else {
    button.textContent = 'Anmelden';
    button.addEventListener('click', login);
    el.append(button);
  }
  $('ask-form').hidden = !state.authenticated;
  $('login-hint').hidden = state.authenticated;
  $('attach-label').hidden = !state.features.attachments;
  $('speaker-panel').hidden = !(state.isSpeaker && state.features.aiSummary);
}

function questionItem(q) {
  const li = document.createElement('li');
  li.className = 'question' + (q.answered ? ' is-answered' : '');

  const vote = document.createElement('button');
  vote.type = 'button';
  vote.className = 'vote' + (q.hasVoted ? ' is-voted' : '');
  vote.disabled = !state.authenticated || q.answered;
  vote.setAttribute('aria-pressed', String(q.hasVoted));
  vote.setAttribute(
    'aria-label',
    `${q.votes} ${q.votes === 1 ? 'Stimme' : 'Stimmen'}. ${q.hasVoted ? 'Stimme zurücknehmen' : 'Für diese Frage stimmen'}`,
  );
  const count = document.createElement('span');
  count.className = 'vote-count';
  count.textContent = q.votes;
  const label = document.createElement('span');
  label.className = 'vote-label';
  label.textContent = q.hasVoted ? 'gestimmt' : q.votes === 1 ? 'Stimme' : 'Stimmen';
  vote.append(count, label);
  vote.addEventListener('click', () => act(`vote-${q.id}`, () => api.vote(q.id)));

  const body = document.createElement('div');
  body.className = 'question-body';
  const text = document.createElement('p');
  text.className = 'question-text';
  text.textContent = q.text;
  const meta = document.createElement('p');
  meta.className = 'question-meta';
  const time = new Date(q.createdAt).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
  meta.textContent = `${q.author}, ${time} Uhr${q.answered ? ' · beantwortet' : ''}`;
  body.append(text);

  if (q.attachmentUrl) {
    const link = document.createElement('a');
    link.href = q.attachmentUrl;
    link.target = '_blank';
    link.rel = 'noopener';
    const img = document.createElement('img');
    img.src = q.attachmentUrl;
    img.alt = 'Angehängter Screenshot';
    img.loading = 'lazy';
    link.append(img);
    body.append(link);
  }
  body.append(meta);

  if (state.isSpeaker) {
    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'link small';
    toggle.textContent = q.answered ? 'Wieder öffnen' : 'Als beantwortet markieren';
    toggle.addEventListener('click', () => act(`answer-${q.id}`, () => api.toggleAnswered(q.id)));
    body.append(toggle);
  }

  li.append(vote, body);
  return li;
}

async function refresh() {
  try {
    const { questions } = await api.questions();
    const open = questions.filter((q) => !q.answered).length;
    $('questions').replaceChildren(...questions.map(questionItem));
    $('empty').hidden = questions.length > 0;
    $('list-count').textContent = questions.length ? `${open} offen, ${questions.length - open} beantwortet` : '';
  } catch (err) {
    $('list-count').textContent = `Liste konnte nicht geladen werden: ${err.message}`;
  }
}

async function act(key, fn) {
  if (state.busy.has(key)) return;
  state.busy.add(key);
  try {
    await fn();
    await refresh();
  } catch (err) {
    alert(err.message);
  } finally {
    state.busy.delete(key);
  }
}

$('question').addEventListener('input', (e) => {
  $('counter').textContent = `${e.target.value.length} / 500`;
});

$('attachment').addEventListener('change', (e) => {
  const file = e.target.files[0];
  $('attach-text').textContent = file ? file.name : 'Screenshot anhängen';
});

$('ask-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const text = $('question').value.trim();
  const file = $('attachment').files[0];
  $('form-error').textContent = '';

  if (text.length < 3) {
    $('form-error').textContent = 'Schreib mindestens drei Zeichen.';
    return;
  }
  if (file && file.size > 5 * 1024 * 1024) {
    $('form-error').textContent = 'Der Screenshot ist größer als 5 MB. Bitte verkleinern.';
    return;
  }

  $('submit').disabled = true;
  $('submit').textContent = 'Wird gesendet …';
  try {
    const attachmentKey = file ? (await api.upload(file)).key : null;
    await api.ask(text, attachmentKey);
    e.target.reset();
    $('counter').textContent = '0 / 500';
    $('attach-text').textContent = 'Screenshot anhängen';
    await refresh();
  } catch (err) {
    $('form-error').textContent = err.message;
  } finally {
    $('submit').disabled = false;
    $('submit').textContent = 'Frage senden';
  }
});

$('login-inline').addEventListener('click', login);

$('summarize').addEventListener('click', async () => {
  const out = $('summary');
  $('summarize').disabled = true;
  out.textContent = 'Das Modell fasst zusammen …';
  try {
    const { summary, model } = await api.summarize();
    out.textContent = summary;
    const note = document.createElement('p');
    note.className = 'question-meta';
    note.textContent = `Erstellt mit ${model} über STACKIT AI Model Serving`;
    out.append(note);
  } catch (err) {
    out.textContent = err.message;
  } finally {
    $('summarize').disabled = false;
  }
});

async function start() {
  state.authenticated = await initAuth();
  try {
    const cfg = await api.config();
    state.features = cfg.features ?? {};
    state.isSpeaker = Boolean(cfg.user?.isSpeaker);
  } catch {
    state.features = {};
  }
  renderSession();
  await refresh();
  // Einfaches Polling reicht für eine Vortragssituation völlig aus.
  setInterval(() => {
    if (document.visibilityState === 'visible') refresh();
  }, 8000);
}

start();
