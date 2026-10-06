// Minimaler JSON-Logger: eine Zeile pro Event, damit STACKIT Observability (Loki) die Felder parsen kann.
function write(level, msg, fields = {}) {
  const line = JSON.stringify({ ts: new Date().toISOString(), level, msg, ...fields });
  (level === 'error' ? process.stderr : process.stdout).write(line + '\n');
}

export const log = {
  info: (msg, fields) => write('info', msg, fields),
  warn: (msg, fields) => write('warn', msg, fields),
  error: (msg, fields) => write('error', msg, fields),
};
