import { describe, expect, it } from 'vitest'

import type { UserAvailableGroup, UserSupportedModelPricing } from '@/api/channels'
import { buildLeaderboard, collectLeaderboardModels, describeModelAbility, formatContext } from '../modelLeaderboard'

function group(id: number, name: string, rate: number, extra: Partial<UserAvailableGroup> = {}): UserAvailableGroup {
  return {
    id,
    name,
    platform: 'openai',
    subscription_type: 'standard',
    rate_multiplier: rate,
    peak_rate_enabled: false,
    peak_start: '',
    peak_end: '',
    peak_rate_multiplier: 1,
    is_exclusive: false,
    ...extra,
  }
}

const tokenPricing: UserSupportedModelPricing = {
  billing_mode: 'token',
  input_price: 0.000002,
  output_price: 0.000006,
  cache_write_price: null,
  cache_read_price: 0.0000005,
  image_input_price: null,
  image_output_price: null,
  per_request_price: null,
  intervals: [],
}

describe('model leaderboard', () => {
  it('ranks flagship models ahead of lighter models and keeps the cheapest group price', () => {
    const rows = buildLeaderboard([
      {
        name: 'claude-haiku-4-5',
        platform: 'anthropic',
        offers: [{ group: group(1, 'Team', 0.02), rate: 0.02, pricing: tokenPricing }],
      },
      {
        name: 'gpt-6-astra',
        platform: 'openai',
        offers: [
          { group: group(2, 'Codex Pro', 0.12), rate: 0.12, pricing: tokenPricing },
          { group: group(3, 'Codex Plus', 0.1), rate: 0.1, pricing: tokenPricing },
        ],
      },
    ], 'ability')

    expect(rows.map((row) => row.name)).toEqual(['gpt-6-astra', 'claude-haiku-4-5'])
    expect(rows[0].ability.tier).toBe('flagship')
    expect(rows[0].best?.groupName).toBe('Codex Plus')
    expect(rows[0].best?.input).toBeCloseTo(0.2)
    expect(rows[0].best?.output).toBeCloseTo(0.6)
    expect(rows[1].ability.tier).toBe('light')
  })


  it('ranks flagships by the Artificial Analysis intelligence index', () => {
    const offer = (rate: number) => [{ group: group(1, 'Default', rate), rate, pricing: tokenPricing }]
    const rows = buildLeaderboard([
      { name: 'claude-haiku-4-5', platform: 'anthropic', offers: offer(0.02) },
      { name: 'glm-5.3-flash', platform: 'zhipu', offers: offer(0.1) },
      { name: 'kimi-k3', platform: 'moonshot', offers: offer(0.1) },
      { name: 'glm-5.3', platform: 'zhipu', offers: offer(0.1) },
      { name: 'grok-4.7', platform: 'grok', offers: offer(0.1) },
      { name: 'gpt-6.1-sol', platform: 'openai', offers: offer(0.1) },
      { name: 'claude-fable-5.1', platform: 'anthropic', offers: offer(0.2) },
      { name: 'gpt-6-astra', platform: 'openai', offers: offer(0.1) },
      { name: 'claude-sonnet-5.5', platform: 'anthropic', offers: offer(0.1) },
      { name: 'claude-opus-5.5', platform: 'anthropic', offers: offer(0.1) },
    ], 'ability')

    expect(rows.map((row) => row.name)).toEqual([
      'claude-opus-5.5',
      'claude-sonnet-5.5',
      'gpt-6-astra',
      'claude-fable-5.1',
      'gpt-6.1-sol',
      'grok-4.7',
      'glm-5.3',
      'kimi-k3',
      'glm-5.3-flash',
      'claude-haiku-4-5',
    ])
    expect(describeModelAbility('claude-opus-5.5').tier).toBe('flagship')
    expect(describeModelAbility('glm-5.3').tier).toBe('flagship')
    expect(describeModelAbility('glm-5.3-flash').tier).not.toBe('flagship')
    expect(describeModelAbility('claude-haiku-4-5').tier).toBe('light')
  })
  it('sorts by the lowest effective price when price ranking is selected', () => {
    const rows = buildLeaderboard([
      {
        name: 'gpt-6-astra',
        platform: 'openai',
        offers: [{ group: group(2, 'Codex Pro', 0.12), rate: 0.12, pricing: tokenPricing }],
      },
      {
        name: 'grok-4.6',
        platform: 'grok',
        offers: [{ group: group(4, 'Grok', 0.18), rate: 0.18, pricing: tokenPricing }],
      },
    ], 'price')

    expect(rows.map((row) => row.name)).toEqual(['gpt-6-astra', 'grok-4.6'])
  })

  it('prices image models per image instead of per million tokens', () => {
    const rows = buildLeaderboard([
      {
        name: 'gpt-image-2',
        platform: 'openai',
        offers: [{
          group: group(3, 'Codex Plus', 0.1, {
            allow_image_generation: true,
            image_rate_independent: true,
            image_rate_multiplier: 0.5,
            image_price_1k: 0.04,
          }),
          rate: 0.1,
          pricing: { ...tokenPricing, billing_mode: 'image', per_request_price: 0.04 },
        }],
      },
    ], 'price')

    expect(rows[0].kind).toBe('image')
    expect(rows[0].ability.features).toEqual(['image'])
    expect(rows[0].best?.unit).toBe('image')
    expect(rows[0].best?.unitPrice).toBeCloseTo(0.02)
    expect(rows[0].best?.input).toBeNull()
  })

  it('describes known capability bands without inventing a context length', () => {
    expect(describeModelAbility('claude-opus-4-6')).toMatchObject({
      tier: 'flagship',
      contextTokens: 200_000,
    })
    expect(describeModelAbility('gemini-3.8-flash').contextTokens).toBe(1_048_576)
    expect(describeModelAbility('gpt-6-astra').contextTokens).toBeNull()
    expect(formatContext(1_048_576)).toBe('1M')
    expect(formatContext(128_000)).toBe('128K')
  })

  it('collects one row per model and applies the user-specific group rate', () => {
    const models = collectLeaderboardModels([
      {
        name: 'OpenAI',
        platforms: [{
          platform: 'openai',
          groups: [group(2, 'Codex Pro', 0.12), group(2, 'Codex Pro', 0.12)],
          supported_models: [{ name: 'gpt-6-astra', platform: 'openai', pricing: tokenPricing }],
        }],
      },
    ], { 2: 0.08 })

    expect(models).toHaveLength(1)
    expect(models[0].offers).toHaveLength(1)
    expect(models[0].offers[0].rate).toBe(0.08)
  })
})
