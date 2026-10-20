import { createDeepSeek } from '@ai-sdk/deepseek';
import { generateText } from 'ai';
import type { H3Event } from 'h3';

export function getDeepSeekModel(event: H3Event) {
  const { apiKey } = useRuntimeConfig(event);

  if (!apiKey) {
    throw createError({
      statusCode: 500,
      statusMessage: 'API key is not configured.',
    });
  }

  return createDeepSeek({ apiKey: apiKey })('deepseek-v4-flash');
}

export async function generateDeepSeekText(event: H3Event, prompt: string) {
  const { text } = await generateText({
    model: getDeepSeekModel(event),
    prompt,
  });

  return text;
}