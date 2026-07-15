<template>
  <AppLayout>
    <main class="mx-auto w-full max-w-[1680px] px-4 py-5 sm:px-6 lg:px-8">
      <div class="mb-5 grid gap-3 lg:grid-cols-[minmax(280px,1.5fr)_repeat(3,minmax(150px,0.65fr))_44px]">
        <div class="relative">
          <Icon
            name="search"
            size="md"
            class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            v-model="searchQuery"
            class="input h-11 pl-10"
            :placeholder="t('modelMarketplace.searchPlaceholder')"
          />
        </div>

        <select v-model="platformFilter" class="input h-11">
          <option value="">{{ t('modelMarketplace.allPlatforms') }}</option>
          <option v-for="platform in platformOptions" :key="platform" :value="platform">
            {{ platformLabel(platform) }}
          </option>
        </select>

        <select v-model="typeFilter" class="input h-11">
          <option value="">{{ t('modelMarketplace.allTypes') }}</option>
          <option value="codex">Codex</option>
          <option value="chat">{{ t('modelMarketplace.types.chat') }}</option>
          <option value="image">{{ t('modelMarketplace.types.image') }}</option>
        </select>

        <select v-model="groupFilter" class="input h-11">
          <option value="">{{ t('modelMarketplace.allGroups') }}</option>
          <option v-for="group in groupOptions" :key="group.id" :value="String(group.id)">
            {{ group.name }}
          </option>
        </select>

        <button
          type="button"
          class="btn btn-secondary h-11 w-11 p-0"
          :title="t('common.refresh')"
          :disabled="loading"
          @click="loadMarketplace"
        >
          <Icon name="refresh" size="md" :class="{ 'animate-spin': loading }" />
        </button>
      </div>

      <div
        v-if="loading && models.length === 0"
        class="flex min-h-[320px] items-center justify-center text-gray-400"
      >
        <Icon name="refresh" size="xl" class="animate-spin" />
      </div>

      <div
        v-else-if="filteredModels.length === 0"
        class="flex min-h-[320px] flex-col items-center justify-center text-gray-400"
      >
        <Icon name="inbox" size="xl" class="mb-3" />
        <p class="text-sm">{{ t('modelMarketplace.empty') }}</p>
      </div>

      <section v-else class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
        <article
          v-for="model in filteredModels"
          :key="`${model.platform}:${model.name}`"
          class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm transition-shadow hover:shadow-md dark:border-dark-700 dark:bg-dark-800"
        >
          <header class="flex min-h-[78px] items-center justify-between gap-3 border-b border-gray-100 px-4 py-3 dark:border-dark-700">
            <div class="flex min-w-0 items-center gap-3">
              <div class="flex h-11 w-11 flex-none items-center justify-center rounded-lg border border-gray-200 bg-gray-50 dark:border-dark-600 dark:bg-dark-700">
                <PlatformIcon :platform="model.platform as GroupPlatform" size="md" />
              </div>
              <div class="min-w-0">
                <h2 class="truncate text-[15px] font-semibold text-gray-900 dark:text-white">
                  {{ displayModelName(model.name) }}
                </h2>
                <p class="mt-0.5 truncate text-xs text-gray-400">{{ model.name }}</p>
              </div>
            </div>
            <span class="flex-none rounded-md border border-gray-200 bg-gray-50 px-2 py-1 text-[11px] text-gray-600 dark:border-dark-600 dark:bg-dark-700 dark:text-gray-300">
              {{ t('modelMarketplace.availableGroups', { count: model.offers.length }) }}
            </span>
          </header>

          <div class="space-y-2 p-3">
            <button
              v-for="offer in model.offers"
              :key="offer.key"
              type="button"
              class="flex min-h-[58px] w-full items-center justify-between gap-3 rounded-lg border border-gray-100 bg-gray-50/70 px-3 py-2 text-left transition-colors hover:border-primary-200 hover:bg-primary-50/50 dark:border-dark-700 dark:bg-dark-900/30 dark:hover:border-primary-700 dark:hover:bg-primary-900/10"
              @click="openPricing(model, offer)"
            >
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="truncate text-sm font-medium text-gray-900 dark:text-white">
                    {{ offer.group.name }}
                  </span>
                  <span class="rounded-md border border-gray-200 bg-white px-1.5 py-0.5 text-[11px] text-gray-600 dark:border-dark-600 dark:bg-dark-800 dark:text-gray-300">
                    x{{ formatRate(offer.effectiveRate) }}
                  </span>
                </div>
                <p class="mt-1 truncate text-[11px] text-gray-400">
                  {{ compactPrice(offer.model.pricing, offer.effectiveRate) }}
                </p>
              </div>
              <span class="flex flex-none items-center gap-1 text-[11px]" :class="statusTextClass(offer.status)">
                <span class="h-1.5 w-1.5 rounded-full" :class="statusDotClass(offer.status)"></span>
                {{ statusLabel(offer.status) }}
              </span>
            </button>
          </div>
        </article>
      </section>
    </main>

    <BaseDialog
      :show="selectedModel !== null && selectedOffer !== null"
      :title="dialogTitle"
      width="wide"
      @close="closePricing"
    >
      <div v-if="selectedModel && selectedOffer" class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-gray-200 bg-gray-50 px-4 py-3 dark:border-dark-600 dark:bg-dark-800">
          <div class="flex min-w-0 items-center gap-3">
            <PlatformIcon :platform="selectedModel.platform as GroupPlatform" size="md" />
            <div class="min-w-0">
              <div class="truncate font-semibold text-gray-900 dark:text-white">{{ selectedModel.name }}</div>
              <div class="mt-0.5 text-xs text-gray-400">{{ selectedOffer.channelName }}</div>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <span class="rounded-md bg-primary-50 px-2 py-1 text-xs font-medium text-primary-600 dark:bg-primary-900/20 dark:text-primary-300">
              x{{ formatRate(selectedOffer.effectiveRate) }}
            </span>
            <span class="rounded-md bg-sky-50 px-2 py-1 text-xs text-sky-600 dark:bg-sky-900/20 dark:text-sky-300">
              {{ billingModeLabel(selectedOffer.model.pricing?.billing_mode) }}
            </span>
          </div>
        </div>

        <div v-if="tierPriceCards.length > 0" class="space-y-3">
          <div class="flex items-center justify-between gap-3">
            <span class="text-sm font-medium text-gray-900 dark:text-white">
              {{ t('modelMarketplace.pricing.contextPricing') }}
            </span>
            <span class="rounded-md bg-gray-100 px-2 py-1 text-xs text-gray-500 dark:bg-dark-700 dark:text-gray-300">
              {{ t('modelMarketplace.pricing.contextTokens') }}
            </span>
          </div>
          <div class="grid gap-3 lg:grid-cols-2">
            <section
              v-for="tier in tierPriceCards"
              :key="tier.key"
              class="overflow-hidden rounded-lg border border-gray-200 dark:border-dark-600"
            >
              <div class="flex items-center justify-between border-b border-gray-200 bg-gray-50 px-3 py-2 dark:border-dark-600 dark:bg-dark-800">
                <span class="text-xs text-gray-500 dark:text-gray-400">
                  {{ t('modelMarketplace.pricing.contextTokens') }}
                </span>
                <span class="text-sm font-medium text-gray-900 dark:text-white">{{ tier.range }}</span>
              </div>
              <div class="divide-y divide-gray-100 px-3 dark:divide-dark-700">
                <div
                  v-for="row in tier.rows"
                  :key="row.label"
                  class="flex min-h-[40px] items-center justify-between gap-4 py-2"
                >
                  <span class="text-sm text-gray-500 dark:text-gray-400">{{ row.label }}</span>
                  <span class="text-sm font-medium text-gray-900 dark:text-white">{{ row.value }}</span>
                </div>
              </div>
            </section>
          </div>
        </div>

        <div v-else-if="priceRows.length > 0" class="grid gap-2 sm:grid-cols-2">
          <div
            v-for="row in priceRows"
            :key="row.label"
            class="flex min-h-[44px] items-center justify-between gap-4 rounded-lg border border-gray-200 px-3 py-2 dark:border-dark-600"
          >
            <span class="text-sm text-gray-500 dark:text-gray-400">{{ row.label }}</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white">{{ row.value }}</span>
          </div>
        </div>
        <p v-else class="py-6 text-center text-sm text-gray-400">{{ t('modelMarketplace.noPricing') }}</p>
      </div>
    </BaseDialog>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseDialog from '@/components/common/BaseDialog.vue'
import Icon from '@/components/icons/Icon.vue'
import PlatformIcon from '@/components/common/PlatformIcon.vue'
import userChannelsAPI, {
  type UserAvailableGroup,
  type UserPricingInterval,
  type UserSupportedModel,
  type UserSupportedModelPricing,
} from '@/api/channels'
import userGroupsAPI from '@/api/groups'
import channelMonitorUserAPI, { type MonitorStatus } from '@/api/channelMonitor'
import { useAppStore } from '@/stores/app'
import { extractApiErrorMessage } from '@/utils/apiError'
import { formatScaled } from '@/utils/pricing'
import type { GroupPlatform } from '@/types'
import {
  BILLING_MODE_IMAGE,
  BILLING_MODE_PER_REQUEST,
  BILLING_MODE_TOKEN,
  type BillingMode,
} from '@/constants/channel'

interface MarketOffer {
  key: string
  channelName: string
  group: UserAvailableGroup
  effectiveRate: number
  model: UserSupportedModel
  status: MonitorStatus | 'unknown'
}

interface MarketModel {
  name: string
  platform: string
  type: 'codex' | 'chat' | 'image'
  offers: MarketOffer[]
}

interface PriceRow {
  label: string
  value: string
}

interface TierPriceCard {
  key: string
  range: string
  rows: PriceRow[]
}

const { t } = useI18n()
const appStore = useAppStore()

const models = ref<MarketModel[]>([])
const loading = ref(false)
const searchQuery = ref('')
const platformFilter = ref('')
const typeFilter = ref('')
const groupFilter = ref('')
const selectedModel = ref<MarketModel | null>(null)
const selectedOffer = ref<MarketOffer | null>(null)

const platformOptions = computed(() =>
  Array.from(new Set(models.value.map((model) => model.platform))).sort(),
)

const groupOptions = computed(() => {
  const groups = new Map<number, UserAvailableGroup>()
  for (const model of models.value) {
    for (const offer of model.offers) groups.set(offer.group.id, offer.group)
  }
  return Array.from(groups.values()).sort((a, b) => a.name.localeCompare(b.name))
})

const filteredModels = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  return models.value.flatMap((model) => {
    if (platformFilter.value && model.platform !== platformFilter.value) return []
    if (typeFilter.value && model.type !== typeFilter.value) return []
    const modelMatchesQuery = !query || (
      model.name.toLowerCase().includes(query) ||
      displayModelName(model.name).toLowerCase().includes(query)
    )
    const offers = model.offers.filter((offer) => {
      if (groupFilter.value && String(offer.group.id) !== groupFilter.value) return false
      if (modelMatchesQuery) return true
      return `${offer.group.name} ${offer.channelName}`.toLowerCase().includes(query)
    })
    return offers.length > 0 ? [{ ...model, offers }] : []
  })
})

const dialogTitle = computed(() => {
  if (!selectedOffer.value) return t('modelMarketplace.pricingTitle')
  return `${selectedOffer.value.group.name} · ${t('modelMarketplace.pricingTitle')}`
})

const priceRows = computed<PriceRow[]>(() => {
  const pricing = selectedOffer.value?.model.pricing
  const rate = selectedOffer.value?.effectiveRate ?? 1
  if (!pricing) return []
  if (pricing.billing_mode === BILLING_MODE_TOKEN) {
    return [
      priceRow(t('modelMarketplace.pricing.input'), pricing.input_price, rate, 1_000_000, '/ 1M Token'),
      priceRow(t('modelMarketplace.pricing.output'), pricing.output_price, rate, 1_000_000, '/ 1M Token'),
      priceRow(t('modelMarketplace.pricing.cacheWrite'), pricing.cache_write_price, rate, 1_000_000, '/ 1M Token'),
      priceRow(t('modelMarketplace.pricing.cacheRead'), pricing.cache_read_price, rate, 1_000_000, '/ 1M Token'),
    ].filter((row): row is PriceRow => row !== null)
  }
  const value = pricing.per_request_price ?? pricing.image_output_price
  const row = priceRow(t('modelMarketplace.pricing.perRequest'), value, rate, 1, '/ Request')
  return row ? [row] : []
})

const tierPriceCards = computed<TierPriceCard[]>(() => {
  const pricing = selectedOffer.value?.model.pricing
  const rate = selectedOffer.value?.effectiveRate ?? 1
  if (!pricing || pricing.billing_mode !== BILLING_MODE_TOKEN || !pricing.intervals?.length) {
    return []
  }
  return pricing.intervals.map((interval, index) => ({
    key: `${interval.min_tokens}:${interval.max_tokens ?? 'infinity'}:${index}`,
    range: formatTokenRange(interval),
    rows: [
      priceRow(t('modelMarketplace.pricing.input'), interval.input_price, rate, 1_000_000, '/ 1M Token'),
      priceRow(t('modelMarketplace.pricing.output'), interval.output_price, rate, 1_000_000, '/ 1M Token'),
      priceRow(t('modelMarketplace.pricing.cacheWrite'), interval.cache_write_price, rate, 1_000_000, '/ 1M Token'),
      priceRow(t('modelMarketplace.pricing.cacheRead'), interval.cache_read_price, rate, 1_000_000, '/ 1M Token'),
    ].filter((row): row is PriceRow => row !== null),
  }))
})

async function loadMarketplace() {
  loading.value = true
  try {
    const [channels, userRates, monitorResponse] = await Promise.all([
      userChannelsAPI.getAvailable(),
      userGroupsAPI.getUserGroupRates().catch(() => ({} as Record<number, number>)),
      channelMonitorUserAPI.list().catch(() => ({ items: [] })),
    ])
    const statusByGroup = new Map(
      monitorResponse.items.map((monitor) => [monitor.group_name, monitor.primary_status || 'unknown']),
    )
    const byModel = new Map<string, MarketModel>()
    for (const channel of channels) {
      for (const section of channel.platforms) {
        for (const supportedModel of section.supported_models) {
          const mapKey = `${section.platform}:${supportedModel.name}`
          const marketModel = byModel.get(mapKey) ?? {
            name: supportedModel.name,
            platform: section.platform,
            type: resolveModelType(supportedModel.name),
            offers: [],
          }
          for (const group of section.groups) {
            const offerKey = `${channel.name}:${group.id}:${supportedModel.name}`
            if (marketModel.offers.some((offer) => offer.key === offerKey)) continue
            marketModel.offers.push({
              key: offerKey,
              channelName: channel.name,
              group,
              effectiveRate: userRates[group.id] ?? group.rate_multiplier,
              model: supportedModel,
              status: statusByGroup.get(group.name) ?? 'unknown',
            })
          }
          marketModel.offers.sort((a, b) => a.effectiveRate - b.effectiveRate)
          byModel.set(mapKey, marketModel)
        }
      }
    }
    models.value = Array.from(byModel.values()).sort((a, b) => a.name.localeCompare(b.name))
  } catch (error: unknown) {
    appStore.showError(extractApiErrorMessage(error, t('modelMarketplace.loadFailed')))
  } finally {
    loading.value = false
  }
}

function resolveModelType(model: string): MarketModel['type'] {
  const value = model.toLowerCase()
  if (value.includes('image') || value.includes('imagen')) return 'image'
  if (value.includes('codex') || value.includes('auto-review')) return 'codex'
  return 'chat'
}

function displayModelName(model: string): string {
  return model
    .split('-')
    .map((part) => {
      if (/^(gpt|codex|claude)$/i.test(part)) return part.toUpperCase()
      return part.charAt(0).toUpperCase() + part.slice(1)
    })
    .join(' ')
}

function platformLabel(platform: string): string {
  const labels: Record<string, string> = {
    openai: 'OpenAI',
    anthropic: 'Anthropic',
    gemini: 'Gemini',
    grok: 'Grok',
  }
  return labels[platform] ?? platform
}

function compactPrice(pricing: UserSupportedModelPricing | null, rate: number): string {
  if (!pricing) return t('modelMarketplace.noPricing')
  if (pricing.billing_mode === BILLING_MODE_TOKEN) {
    if (pricing.intervals?.length) return t('modelMarketplace.pricing.contextPricing')
    return `${t('modelMarketplace.pricing.input')} ${effectivePrice(pricing.input_price, rate, 1_000_000)} · ${t('modelMarketplace.pricing.output')} ${effectivePrice(pricing.output_price, rate, 1_000_000)}`
  }
  return `${t('modelMarketplace.pricing.perRequest')} ${effectivePrice(pricing.per_request_price ?? pricing.image_output_price, rate, 1)}`
}

function formatTokenRange(interval: UserPricingInterval): string {
  const min = interval.min_tokens.toLocaleString()
  const max = interval.max_tokens == null
    ? t('modelMarketplace.pricing.infinity')
    : interval.max_tokens.toLocaleString()
  return `${min} - ${max}`
}

function effectivePrice(value: number | null, rate: number, scale: number): string {
  return formatScaled(value == null ? null : value * rate, scale)
}

function priceRow(
  label: string,
  value: number | null,
  rate: number,
  scale: number,
  unit: string,
): PriceRow | null {
  if (value == null) return null
  return { label, value: `${effectivePrice(value, rate, scale)} USD ${unit}` }
}

function formatRate(rate: number): string {
  return Number(rate.toFixed(4)).toString()
}

function billingModeLabel(mode?: BillingMode): string {
  if (mode === BILLING_MODE_TOKEN) return t('modelMarketplace.billing.token')
  if (mode === BILLING_MODE_IMAGE) return t('modelMarketplace.billing.image')
  if (mode === BILLING_MODE_PER_REQUEST) return t('modelMarketplace.billing.request')
  return '-'
}

function statusLabel(status: MarketOffer['status']): string {
  return t(`monitorCommon.status.${status}`)
}

function statusDotClass(status: MarketOffer['status']): string {
  if (status === 'operational') return 'bg-emerald-500'
  if (status === 'degraded') return 'bg-amber-500'
  if (status === 'failed' || status === 'error') return 'bg-red-500'
  return 'bg-gray-400'
}

function statusTextClass(status: MarketOffer['status']): string {
  if (status === 'operational') return 'text-emerald-600 dark:text-emerald-400'
  if (status === 'degraded') return 'text-amber-600 dark:text-amber-400'
  if (status === 'failed' || status === 'error') return 'text-red-600 dark:text-red-400'
  return 'text-gray-400'
}

function openPricing(model: MarketModel, offer: MarketOffer) {
  selectedModel.value = model
  selectedOffer.value = offer
}

function closePricing() {
  selectedModel.value = null
  selectedOffer.value = null
}

onMounted(loadMarketplace)
</script>
