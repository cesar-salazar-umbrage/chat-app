const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const philosopherPrompts = require('./philosopherPrompts');
const OpenAI = require('openai');

initializeApp();

// Shared helper to build the prompt and call OpenAI
async function generatePhilosopherResponse({ message, philosopherId, conversationHistory }) {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY || require('firebase-functions').config().openai.key,
  });

  const philosopherConfig = philosopherPrompts[philosopherId];
  if (!philosopherConfig) {
    throw new Error(`Unknown philosopher: ${philosopherId}`);
  }

  const recentHistory = (conversationHistory || []).slice(-10);

  const messages = [
    { role: 'system', content: philosopherConfig.systemPrompt },
    ...recentHistory.map((msg) => {
      if (msg.startsWith('Human:')) {
        return { role: 'user', content: msg.replace('Human: ', '') };
      } else if (msg.startsWith(`${philosopherId}:`)) {
        return { role: 'assistant', content: msg.replace(`${philosopherId}: `, '') };
      }
      return null;
    }).filter(Boolean),
    { role: 'user', content: message }
  ];

  const completion = await openai.chat.completions.create({
    model: 'gpt-3.5-turbo',
    messages,
    max_tokens: 500,
    temperature: 0.8,
    presence_penalty: 0.1,
    frequency_penalty: 0.1,
  });

  const response = completion.choices[0]?.message?.content;
  if (!response) {
    throw new Error('No response from OpenAI');
  }

  return response.trim();
}

// ─────────────── onCall Version (for Flutter SDK) ───────────────
exports.getPhilosopherResponseCallable = onCall(async (request) => {
  const { message, philosopherId, conversationHistory } = request.data || {};

  if (!message || typeof message !== 'string') {
    throw new HttpsError('invalid-argument', 'Message is required and must be a string');
  }
  if (!philosopherId || typeof philosopherId !== 'string') {
    throw new HttpsError('invalid-argument', 'Philosopher ID is required and must be a string');
  }

  try {
    const response = await generatePhilosopherResponse({ message, philosopherId, conversationHistory });
    return { success: true, response };
  } catch (error) {
    logger.error('Callable function error', { error: error.message });
    throw new HttpsError('internal', error.message || 'Failed to generate response');
  }
});

// ─────────────── onRequest Version (for curl/Postman) ───────────────
exports.getPhilosopherResponse = onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(204).send('');

  const { message, philosopherId, conversationHistory } = req.body || {};

  if (!message || typeof message !== 'string') {
    return res.status(400).json({ success: false, error: 'Message is required and must be a string' });
  }
  if (!philosopherId || typeof philosopherId !== 'string') {
    return res.status(400).json({ success: false, error: 'Philosopher ID is required and must be a string' });
  }

  try {
    const response = await generatePhilosopherResponse({ message, philosopherId, conversationHistory });
    return res.status(200).json({ success: true, response });
  } catch (error) {
    logger.error('HTTP function error', { error: error.message });
    return res.status(500).json({ success: false, error: error.message || 'Failed to generate response' });
  }
});

// ─────────────── Test Route ───────────────
exports.testPhilosopherResponse = onRequest((req, res) => {
  res.status(200).json({
    message: 'Cloud Function is working!',
    timestamp: new Date().toISOString(),
    philosophersAvailable: Object.keys(philosopherPrompts),
  });
});
