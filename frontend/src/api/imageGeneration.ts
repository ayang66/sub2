import { buildGatewayUrl } from './client'

export interface ImageGenerationRequest {
  model: string
  prompt: string
  size?: string
  n?: number
  response_format?: 'b64_json' | 'url'
}

export interface ImageGenerationResponse {
  data?: Array<{ b64_json?: string; url?: string; revised_prompt?: string }>
}

async function parseError(response: Response): Promise<Error> {
  try {
    const body = await response.json()
    return new Error(body?.error?.message || body?.message || response.statusText)
  } catch {
    return new Error(response.statusText || `HTTP ${response.status}`)
  }
}

export async function generateImage(apiKey: string, payload: ImageGenerationRequest): Promise<ImageGenerationResponse> {
  const response = await fetch(buildGatewayUrl('/v1/images/generations'), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  })
  if (!response.ok) throw await parseError(response)
  return response.json()
}

export async function sendChatMessage(apiKey: string, model: string, input: string): Promise<unknown> {
  const response = await fetch(buildGatewayUrl('/v1/responses'), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ model, input, max_output_tokens: 800 }),
  })
  if (!response.ok) throw await parseError(response)
  return response.json()
}

export function extractResponseText(response: any): string {
  if (typeof response?.output_text === 'string') return response.output_text
  const chunks = response?.output?.flatMap((item: any) => item?.content || []) || []
  return chunks.map((chunk: any) => chunk?.text || '').filter(Boolean).join('') || '已收到你的消息。'
}
