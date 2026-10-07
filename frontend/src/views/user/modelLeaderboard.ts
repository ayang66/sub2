import type { UserAvailableGroup, UserSupportedModel, UserSupportedModelPricing } from '@/api/channels'
import {
  BILLING_MODE_IMAGE,
  BILLING_MODE_PER_REQUEST,
  BILLING_MODE_TOKEN,
  BILLING_MODE_VIDEO,
} from '@/constants/channel'

export type LeaderboardSort = 'ability' | 'price'
export type ModelKind = 'chat' | 'codex' | 'image' | 'video'
export type AbilityTier = 'flagship' | 'strong' | 'balanced' | 'light' | 'media'
export type AbilityFeature = 'reasoning' | 'code' | 'longContext' | 'vision' | 'image' | 'video'
export type PriceUnit = 'tokens' | 'image' | 'request' | 'video'

export interface ModelAbility {
  tier: AbilityTier
  contextTokens: number | null
  features: AbilityFeature[]
}

export interface LeaderboardQuote {
  groupId: number
  groupName: string
  rate: number
  input: number | null
  output: number | null
  unitPrice: number | null
  unit: PriceUnit
  tiered: boolean
}

export interface LeaderboardOfferInput {
  group: UserAvailableGroup
  rate: number
  pricing: UserSupportedModelPricing | null
}

export interface LeaderboardModelInput {
  name: string
  platform: string
  offers: LeaderboardOfferInput[]
}

export interface LeaderboardRow {
  name: string
  platform: string
  kind: ModelKind
  ability: ModelAbility
  quotes: LeaderboardQuote[]
  best: LeaderboardQuote | null
}

interface LeaderboardChannel {
  name: string
  platforms: Array<{
    platform: string
    groups: UserAvailableGroup[]
    supported_models: UserSupportedModel[]
  }>
}

const TIER_RANK: Record<AbilityTier, number> = {
  flagship: 0,
  strong: 1,
  balanced: 2,
  light: 3,
  media: 4,
}

// Artificial Analysis Intelligence Index integers, highest published reasoning setting.
// Captured 2026-10-08 from https://artificialanalysis.ai/leaderboards/models.
// Only scores present on that leaderboard are listed. Unlisted models keep a tier baseline.
const TIER_ABILITY_BASELINE: Record<AbilityTier, number> = {
  flagship: 21,
  strong: 14,
  balanced: 8,
  light: 3,
  media: 0,
}

const INTELLIGENCE_RULES: Array<{ pattern: RegExp; score: number }> = [
  { pattern: /^claude-opus-5-5(?:-|$)/, score: 58 },
  { pattern: /^claude-sonnet-5-5(?:-|$)/, score: 56 },
  { pattern: /^claude-fable-5-1(?:-|$)/, score: 53 },
  { pattern: /^gpt-6-astra(?:-|$)/, score: 53 },
  { pattern: /^gpt-6-1-sol(?:-|$)/, score: 52 },
  { pattern: /^grok-4-7(?:-|$)/, score: 46 },
  { pattern: /^qwen3-8-max(?:-|$)/, score: 45 },
  { pattern: /^glm-5-3-flash(?:-|$)/, score: 42 },
  { pattern: /^glm-5-3$/, score: 45 },
  { pattern: /^kimi-k3(?:-|$)/, score: 44 },
  { pattern: /^claude-haiku-5-5(?:-|$)/, score: 43 },
  { pattern: /^gpt-5-6-terra(?:-|$)/, score: 42 },
  { pattern: /^gemini-3-8-flash(?:-|$)/, score: 41 },
  { pattern: /^gpt-6-luna(?:-|$)/, score: 38 },
  { pattern: /^deepseek-v4-1-flash(?:-|$)/, score: 39 },
  { pattern: /^deepseek-v4-pro-0813(?:-|$)/, score: 36 },
  { pattern: /^deepseek-v4-flash-vision(?:-|$)/, score: 35 },
  { pattern: /^gemini-3-1-pro(?:-|$)/, score: 30 },
  { pattern: /^minimax-m3(?:-|$)/, score: 29 },
]

function canonicalModelName(modelName: string): string {
  return modelName
    .toLowerCase()
    .replace(/\[[^\]]*\]/g, '')
    .replace(/-thinking$/, '')
    .replace(/(\d)\.(\d)/g, '$1-$2')
}

function intelligenceScore(modelName: string): number | null {
  const name = canonicalModelName(modelName)
  if (
    /(^|[-_])mini($|[-_])/.test(name)
    || name.includes('lite')
    || name.includes('nano')
    || name.includes('flash-lite')
    || name.startsWith('glm-5-2-fast')
  ) {
    return null
  }
  return INTELLIGENCE_RULES.find((rule) => rule.pattern.test(name))?.score ?? null
}

function abilityRank(row: LeaderboardRow): number {
  return intelligenceScore(row.name) ?? TIER_ABILITY_BASELINE[row.ability.tier]
}

export function collectLeaderboardModels(
  channels: LeaderboardChannel[],
  userRates: Record<number, number>,
): LeaderboardModelInput[] {
  const byModel = new Map<string, LeaderboardModelInput>()
  for (const channel of channels) {
    for (const section of channel.platforms) {
      for (const supportedModel of section.supported_models) {
        const key = `${section.platform}:${supportedModel.name}`
        const model = byModel.get(key) ?? {
          name: supportedModel.name,
          platform: section.platform,
          offers: [],
        }
        for (const group of section.groups) {
          if (model.offers.some((offer) => offer.group.id === group.id)) continue
          model.offers.push({
            group,
            rate: userRates[group.id] ?? group.rate_multiplier,
            pricing: supportedModel.pricing,
          })
        }
        byModel.set(key, model)
      }
    }
  }
  return Array.from(byModel.values())
}

export function buildLeaderboard(models: LeaderboardModelInput[], sort: LeaderboardSort): LeaderboardRow[] {
  return models
    .map((model) => {
      const quotes = model.offers
        .map((offer) => quoteFor(model.name, offer))
        .sort((a, b) => comparePrice(a, b) || a.groupName.localeCompare(b.groupName))
      return {
        name: model.name,
        platform: model.platform,
        kind: modelKind(model.name),
        ability: describeModelAbility(model.name),
        quotes,
        best: quotes[0] ?? null,
      }
    })
    .sort((a, b) => compareRows(a, b, sort))
}

export function describeModelAbility(modelName: string): ModelAbility {
  const name = modelName.toLowerCase()
  const kind = modelKind(name)
  if (kind === 'image' || kind === 'video') {
    return {
      tier: 'media',
      contextTokens: null,
      features: [kind === 'image' ? 'image' : 'video'],
    }
  }

  const light = isLightModel(name)
  const score = intelligenceScore(modelName)
  const tier = score != null && score >= 43 ? 'flagship' : resolveTier(name, light)
  const contextTokens = resolveContext(name)
  const features: AbilityFeature[] = []
  if (tier === 'flagship' || tier === 'strong' || name.includes('reason') || name.includes('think')) {
    features.push('reasoning')
  }
  if (kind === 'codex') features.push('code')
  if (contextTokens != null && contextTokens >= 200_000) features.push('longContext')
  if (!light && supportsVision(name)) features.push('vision')
  return { tier, contextTokens, features }
}

export function formatContext(tokens: number | null): string | null {
  if (tokens == null) return null
  if (tokens >= 1_000_000) {
    const millions = tokens / 1_000_000
    return `${Number(millions.toFixed(1))}M`
  }
  if (tokens >= 1_000) return `${Math.round(tokens / 1000)}K`
  return String(tokens)
}

export function modelKind(modelName: string): ModelKind {
  const name = modelName.toLowerCase()
  if (name.includes('image') || name.includes('imagen') || name.includes('seedream') || name.includes('dall-e')) {
    return 'image'
  }
  if (name.includes('seedance') || name.includes('veo') || name.includes('sora') || name.includes('video')) {
    return 'video'
  }
  if (name.includes('codex') || name.includes('auto-review')) return 'codex'
  return 'chat'
}

function resolveTier(name: string, light: boolean): AbilityTier {
  if (light) return 'light'
  if (isFlagship(name)) return 'flagship'
  if (name.includes('sonnet') || name.includes('flash') || name.includes('codex') || name.includes('pro')) {
    return 'strong'
  }
  return 'balanced'
}

function isFlagship(name: string): boolean {
  return [
    'opus',
    'fable',
    'gpt-5',
    'gpt-6',
    'grok-4',
    'gemini-2.5-pro',
    'gemini-3-pro',
    'gemini-3.1-pro',
  ].some((part) => name.includes(part)) || /(^|[-_])o[134]($|[-_])/.test(name)
}

function isLightModel(name: string): boolean {
  return name.includes('nano')
    || name.includes('haiku')
    || name.includes('flash-lite')
    || name.includes('lite')
    || /(^|[-_])mini($|[-_])/.test(name)
}

function supportsVision(name: string): boolean {
  return ['gpt-4o', 'gpt-5', 'gpt-6', 'claude', 'gemini', 'grok', 'vision'].some((part) => name.includes(part))
}

function resolveContext(name: string): number | null {
  if (name.includes('gpt-4o')) return 128_000
  if (name.includes('gpt-4.1')) return 1_047_576
  if (name.includes('gemini')) return 1_048_576
  if (name.includes('claude-3') || name.includes('claude-4') || name.includes('claude-opus') || name.includes('claude-sonnet') || name.includes('claude-haiku')) {
    return 200_000
  }
  return null
}

function quoteFor(modelName: string, offer: LeaderboardOfferInput): LeaderboardQuote {
  const pricing = offer.pricing
  const base = {
    groupId: offer.group.id,
    groupName: offer.group.name,
    rate: offer.rate,
  }
  if (modelKind(modelName) === 'image' && offer.group.allow_image_generation) {
    const multiplier = offer.group.image_rate_independent
      ? (offer.group.image_rate_multiplier ?? 1)
      : offer.rate
    const unitPrice = firstNumber(
      offer.group.image_price_1k,
      offer.group.image_price_2k,
      offer.group.image_price_4k,
    )
    return { ...base, input: null, output: null, unitPrice: scale(unitPrice, multiplier), unit: 'image', tiered: false }
  }
  if (pricing?.billing_mode === BILLING_MODE_IMAGE) {
    return {
      ...base,
      input: null,
      output: null,
      unitPrice: scale(pricing.image_output_price ?? pricing.per_request_price, offer.rate),
      unit: 'image',
      tiered: false,
    }
  }
  if (pricing?.billing_mode === BILLING_MODE_PER_REQUEST) {
    return {
      ...base,
      input: null,
      output: null,
      unitPrice: scale(pricing.per_request_price, offer.rate),
      unit: 'request',
      tiered: false,
    }
  }
  if (pricing?.billing_mode === BILLING_MODE_VIDEO) {
    return {
      ...base,
      input: null,
      output: null,
      unitPrice: scale(pricing.per_request_price, offer.rate),
      unit: 'video',
      tiered: false,
    }
  }
  const interval = pricing?.billing_mode === BILLING_MODE_TOKEN ? pricing.intervals?.[0] : undefined
  return {
    ...base,
    input: scaleMillion(pricing?.input_price ?? interval?.input_price ?? null, offer.rate),
    output: scaleMillion(pricing?.output_price ?? interval?.output_price ?? null, offer.rate),
    unitPrice: null,
    unit: 'tokens',
    tiered: (pricing?.intervals?.length ?? 0) > 1,
  }
}

function firstNumber(...values: Array<number | null | undefined>): number | null {
  for (const value of values) {
    if (value != null) return value
  }
  return null
}

function scale(value: number | null, rate: number): number | null {
  return value == null ? null : value * rate
}

function scaleMillion(value: number | null, rate: number): number | null {
  return value == null ? null : value * rate * 1_000_000
}

function priceKey(quote: LeaderboardQuote | null): number {
  if (!quote) return Number.POSITIVE_INFINITY
  const value = quote.unit === 'tokens' ? quote.input : quote.unitPrice
  return value == null ? Number.POSITIVE_INFINITY : value
}

function comparePrice(a: LeaderboardQuote, b: LeaderboardQuote): number {
  return priceKey(a) - priceKey(b)
}

function compareRows(a: LeaderboardRow, b: LeaderboardRow, sort: LeaderboardSort): number {
  if (sort === 'price') {
    return priceKey(a.best) - priceKey(b.best) || a.name.localeCompare(b.name)
  }
  const abilityDifference = abilityRank(b) - abilityRank(a)
  if (abilityDifference) return abilityDifference
  const tierDifference = TIER_RANK[a.ability.tier] - TIER_RANK[b.ability.tier]
  if (tierDifference) return tierDifference
  const contextDifference = (b.ability.contextTokens ?? -1) - (a.ability.contextTokens ?? -1)
  if (contextDifference) return contextDifference
  return priceKey(a.best) - priceKey(b.best) || a.name.localeCompare(b.name)
}
