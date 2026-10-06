// STACKIT AI Model Serving spricht das OpenAI-Protokoll. Ein plain fetch reicht,
// alternativ funktioniert das offizielle "openai"-SDK mit baseURL.
export function createAi(ai) {
  if (!ai) return null;

  async function summarize(questions) {
    const list = questions.map((q, i) => `${i + 1}. (${q.votes} Stimmen) ${q.text}`).join('\n');

    const res = await fetch(`${ai.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${ai.apiKey}` },
      body: JSON.stringify({
        model: ai.model,
        temperature: 0.2,
        max_tokens: 600,
        messages: [
          {
            role: 'system',
            content:
              'Du hilfst einem Speaker auf einer Tech-Konferenz. Fasse die offenen Publikumsfragen ' +
              'auf Deutsch in höchstens fünf Themenblöcken zusammen. Nenne pro Block die Kernfrage ' +
              'in einem Satz und wie viele Stimmen dahinterstehen. Erfinde nichts dazu.',
          },
          { role: 'user', content: list },
        ],
      }),
      signal: AbortSignal.timeout(30_000),
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      throw new Error(`AI Model Serving antwortete mit ${res.status}: ${detail.slice(0, 200)}`);
    }
    const data = await res.json();
    return data.choices?.[0]?.message?.content?.trim() ?? '';
  }

  return { summarize, model: ai.model };
}
