// Budget Buddy — receipt-scan proxy (Cloudflare Worker)
//
// Holds the Gemini API key server-side so it never ships inside the app.
// The endpoint can ONLY scan receipts (prompt + schema are fixed here), so
// even if someone finds your worker URL they can't use it as a general
// AI proxy — the worst they can do is scan receipts against your free quota.
//
// Deploy (one-time, ~5 minutes, free — no card needed):
//   1. Sign up at dash.cloudflare.com (free plan).
//   2. npm create cloudflare@latest bb-receipt-scan -- --template=hello-world
//   3. Replace the generated src/index.js with this file.
//   4. npx wrangler secret put GEMINI_API_KEY   (paste your key when asked)
//   5. npx wrangler deploy                      (prints your worker URL)
//
// Then build the app with:
//   flutter build ios --dart-define=SCAN_PROXY_URL=https://bb-receipt-scan.<your-account>.workers.dev

const MODELS = ['gemini-flash-latest', 'gemini-3.5-flash', 'gemini-2.5-flash'];

const PROMPT =
  'Read this receipt. Extract the merchant name, the final total paid, ' +
  'the purchase date, and pick the best matching expense category from ' +
  'the allowed list.';

const CATEGORIES = [
  'Food & Dining', 'Transport', 'Shopping', 'Entertainment',
  'Bills & Utilities', 'Health', 'Education', 'Other',
];

// ~8MB of base64 ≈ 6MB image — far above what the app sends (1600px jpeg).
const MAX_BASE64_LENGTH = 11_000_000;

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'POST only' }, 405);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: 'invalid JSON body' }, 400);
    }
    const { mimeType, data } = payload ?? {};
    if (
      typeof mimeType !== 'string' || !mimeType.startsWith('image/') ||
      typeof data !== 'string' || data.length === 0 ||
      data.length > MAX_BASE64_LENGTH
    ) {
      return json({ error: 'expected {mimeType: "image/...", data: "<base64>"}' }, 400);
    }

    const body = JSON.stringify({
      contents: [{
        parts: [
          { text: PROMPT },
          { inlineData: { mimeType, data } },
        ],
      }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: 'OBJECT',
          properties: {
            merchant: { type: 'STRING' },
            total: { type: 'NUMBER' },
            date: { type: 'STRING', description: 'Purchase date as YYYY-MM-DD, if visible' },
            category: { type: 'STRING', enum: CATEGORIES },
          },
          required: ['merchant', 'total'],
        },
      },
    });

    for (let i = 0; i < MODELS.length; i++) {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${MODELS[i]}:generateContent?key=${env.GEMINI_API_KEY}`,
        { method: 'POST', headers: { 'Content-Type': 'application/json' }, body },
      );
      if (response.status === 404 && i < MODELS.length - 1) continue;
      // Pass Gemini's response straight through — the app parses it the same
      // way as a direct call. The key itself never appears in any response.
      return new Response(await response.text(), {
        status: response.status,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    return json({ error: 'no Gemini model available' }, 502);
  },
};
