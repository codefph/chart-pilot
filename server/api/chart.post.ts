import { z } from 'zod';
import { generateChartForPrompt } from '../utils/chart-generator';

const requestSchema = z.object({
  prompt: z.string().trim().min(1).max(2_000),
}).strict();

export default defineEventHandler(async (event) => {
  const body = await readBody<unknown>(event);
  const parsed = requestSchema.safeParse(body);

  if (!parsed.success) {
    throw createError({
      statusCode: 400,
      statusMessage: 'Provide a chart request in the prompt field (up to 2000 characters).',
    });
  }

  return generateChartForPrompt(event, parsed.data.prompt);
});
