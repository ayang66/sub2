<template>
  <AppLayout>
    <main class="mx-auto w-full max-w-[1680px] px-4 py-5 sm:px-6 lg:px-8">
      <div class="mb-4 grid gap-3 lg:grid-cols-[minmax(240px,1.4fr)_repeat(2,minmax(140px,0.6fr))_auto_44px]">
        <div class="relative">
          <Icon
            name="search"
            size="md"
            class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
          />
          <input
            v-model="searchQuery"
            class="input h-11 pl-10"
            :placeholder="t('modelLeaderboard.searchPlaceholder')"
          />
        </div>

        <select v-model="platformFilter" class="input h-11">
          <option value="">{{ t('modelLeaderboard.allPlatforms') }}</option>
          <option v-for="platform in platformOptions" :key="platform" :value="platform">
            {{ platformLabel(platform) }}
          </option>
        </select>

        <select v-model="kindFilter" class="input h-11">
          <option value="">{{ t('modelLeaderboard.allTypes') }}</option>
          <option value="chat">{{ t('modelLeaderboard.types.chat') }}</option>
          <option value="codex">Codex</option>
          <option value="image">{{ t('modelLeaderboard.types.image') }}</option>
          <option value="video">{{ t('modelLeaderboard.types.video') }}</option>
        </select>

        <div class="inline-flex h-11 overflow-hidden rounded-lg border border-gray-200 dark:border-dark-600">
          <button
            type="button"
            class="px-3 text-sm"
            :class="sortButtonClass('ability')"
            @click="sort = 'ability'"
          >
            {{ t('modelLeaderboard.sortAbility') }}
          </button>
          <button
            type="button"
            class="border-l border-gray-200 px-3 text-sm dark:border-dark-600"
            :class="sortButtonClass('price')"
            @click="sort = 'price'"
          >
            {{ t('modelLeaderboard.sortPrice') }}
          </button>
        </div>

        <button
          type="button"
          class="btn btn-secondary h-11 w-11 p-0"
          :title="t('common.refresh')"
          :disabled="loading"
          @click="loadLeaderboard"
        >
          <Icon name="refresh" size="md" :class="{ 'animate-spin': loading }" />
        </button>
      </div>

      <div
        v-if="loading && sourceModels.length === 0"
        class="flex min-h-[320px] items-center justify-center text-gray-400"
      >
        <Icon name="refresh" size="xl" class="animate-spin" />
      </div>

      <div
        v-else-if="visibleRows.length === 0"
        class="flex min-h-[320px] flex-col items-center justify-center text-gray-400"
      >
        <Icon name="inbox" size="xl" class="mb-3" />
        <p class="text-sm">{{ t('modelLeaderboard.empty') }}</p>
      </div>

      <div v-else class="overflow-x-auto rounded-lg border border-gray-200 dark:border-dark-700">
        <table class="w-full min-w-[980px] border-collapse text-sm">
          <thead class="bg-gray-50 text-left text-xs text-gray-500 dark:bg-dark-800 dark:text-gray-400">
            <tr>
              <th class="w-14 px-3 py-2 font-medium">{{ t('modelLeaderboard.columns.rank') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('modelLeaderboard.columns.model') }}</th>
              <th class="w-56 px-3 py-2 font-medium">{{ t('modelLeaderboard.columns.ability') }}</th>
              <th class="w-24 px-3 py-2 font-medium">{{ t('modelLeaderboard.columns.context') }}</th>
              <th class="w-32 px-3 py-2 text-right font-medium">{{ t('modelLeaderboard.columns.input') }}</th>
              <th class="w-32 px-3 py-2 text-right font-medium">{{ t('modelLeaderboard.columns.output') }}</th>
              <th class="w-52 px-3 py-2 font-medium">{{ t('modelLeaderboard.columns.group') }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="(row, index) in visibleRows" :key="`${row.platform}:${row.name}`">
              <tr
                class="cursor-pointer border-t border-gray-100 hover:bg-gray-50 dark:border-dark-700 dark:hover:bg-dark-800/70"
                :data-model="row.name"
                @click="toggleRow(row)"
              >
                <td class="px-3 py-3 align-middle" :class="index < 3 ? 'font-semibold text-gray-900 dark:text-white' : 'text-gray-400'">
                  {{ index + 1 }}
                </td>
                <td class="px-3 py-3 align-middle">
                  <div class="flex items-center gap-2">
                    <PlatformIcon :platform="row.platform as GroupPlatform" size="sm" />
                    <div class="min-w-0">
                      <div class="truncate font-medium text-gray-900 dark:text-white">{{ displayModelName(row.name) }}</div>
                      <div class="truncate text-xs text-gray-400">{{ row.name }}</div>
                    </div>
                  </div>
                </td>
                <td class="px-3 py-3 align-middle">
                  <div class="flex flex-wrap gap-1">
                    <span class="rounded border border-gray-200 px-1.5 py-0.5 text-[11px] text-gray-700 dark:border-dark-600 dark:text-gray-200">
                      {{ t(`modelLeaderboard.tiers.${row.ability.tier}`) }}
                    </span>
                    <span
                      v-for="feature in row.ability.features"
                      :key="feature"
                      class="rounded border border-gray-200 px-1.5 py-0.5 text-[11px] text-gray-500 dark:border-dark-600 dark:text-gray-400"
                    >
                      {{ t(`modelLeaderboard.features.${feature}`) }}
                    </span>
                  </div>
                </td>
                <td class="px-3 py-3 align-middle text-gray-700 dark:text-gray-200">
                  {{ formatContext(row.ability.contextTokens) ?? t('modelLeaderboard.contextUnknown') }}
                </td>
                <td class="px-3 py-3 text-right align-middle font-medium text-gray-900 dark:text-white">
                  {{ priceText(row.best, 'input') }}
                </td>
                <td class="px-3 py-3 text-right align-middle text-gray-700 dark:text-gray-200">
                  {{ priceText(row.best, 'output') }}
                </td>
                <td class="px-3 py-3 align-middle">
                  <div v-if="row.best" class="min-w-0">
                    <div class="truncate text-gray-900 dark:text-white">{{ row.best.groupName }}</div>
                    <div class="text-xs text-gray-400">
                      x{{ formatRate(row.best.rate) }}
                      <span v-if="row.best.tiered"> · {{ t('modelLeaderboard.tiered') }}</span>
                      <span v-if="row.quotes.length > 1"> · {{ t('modelLeaderboard.moreGroups', { count: row.quotes.length - 1 }) }}</span>
                    </div>
                  </div>
                  <span v-else class="text-gray-400">{{ t('modelLeaderboard.noPrice') }}</span>
                </td>
              </tr>
              <tr v-if="expandedKey === rowKey(row)" class="border-t border-gray-100 bg-gray-50/70 dark:border-dark-700 dark:bg-dark-900/40">
                <td colspan="7" class="px-3 py-2">
                  <table class="w-full text-xs">
                    <tbody>
                      <tr v-for="quote in row.quotes" :key="quote.groupId" class="border-t border-gray-100 first:border-t-0 dark:border-dark-700">
                        <td class="w-[42%] py-1.5 pr-3 text-gray-700 dark:text-gray-200">{{ quote.groupName }}</td>
                        <td class="w-16 py-1.5 text-gray-400">x{{ formatRate(quote.rate) }}</td>
                        <td class="py-1.5 text-right text-gray-900 dark:text-white">{{ priceText(quote, 'input') }}</td>
                        <td class="w-32 py-1.5 text-right text-gray-600 dark:text-gray-300">{{ priceText(quote, 'output') }}</td>
                      </tr>
                    </tbody>
                  </table>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </main>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import userChannelsAPI from '@/api/channels'
import userGroupsAPI from '@/api/groups'
import AppLayout from '@/components/layout/AppLayout.vue'
import PlatformIcon from '@/components/common/PlatformIcon.vue'
import Icon from '@/components/icons/Icon.vue'
import { useAppStore } from '@/stores/app'
import { extractApiErrorMessage } from '@/utils/apiError'
import { formatScaled } from '@/utils/pricing'
import type { GroupPlatform } from '@/types'
import {
  buildLeaderboard,
  collectLeaderboardModels,
  formatContext,
  modelKind,
  type LeaderboardModelInput,
  type LeaderboardQuote,
  type LeaderboardRow,
  type LeaderboardSort,
} from './modelLeaderboard'

const { t } = useI18n()
const appStore = useAppStore()

const sourceModels = ref<LeaderboardModelInput[]>([])
const loading = ref(false)
const searchQuery = ref('')
const platformFilter = ref('')
const kindFilter = ref('')
const sort = ref<LeaderboardSort>('ability')
const expandedKey = ref('')

const platformOptions = computed(() =>
  Array.from(new Set(sourceModels.value.map((model) => model.platform))).sort(),
)

const visibleRows = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  const filtered = sourceModels.value.filter((model) => {
    if (platformFilter.value && model.platform !== platformFilter.value) return false
    if (kindFilter.value && modelKind(model.name) !== kindFilter.value) return false
    if (!query) return true
    return model.name.toLowerCase().includes(query) || displayModelName(model.name).toLowerCase().includes(query)
  })
  return buildLeaderboard(filtered, sort.value)
})

async function loadLeaderboard() {
  loading.value = true
  try {
    const [channels, userRates] = await Promise.all([
      userChannelsAPI.getAvailable(),
      userGroupsAPI.getUserGroupRates().catch(() => ({} as Record<number, number>)),
    ])
    sourceModels.value = collectLeaderboardModels(channels, userRates)
  } catch (error: unknown) {
    appStore.showError(extractApiErrorMessage(error, t('modelLeaderboard.loadFailed')))
  } finally {
    loading.value = false
  }
}

function sortButtonClass(value: LeaderboardSort): string {
  return sort.value === value
    ? 'bg-gray-900 text-white dark:bg-white dark:text-gray-900'
    : 'bg-white text-gray-600 dark:bg-dark-800 dark:text-gray-300'
}

function rowKey(row: LeaderboardRow): string {
  return `${row.platform}:${row.name}`
}

function toggleRow(row: LeaderboardRow) {
  const key = rowKey(row)
  expandedKey.value = expandedKey.value === key ? '' : key
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

function formatRate(rate: number): string {
  return Number(rate.toFixed(4)).toString()
}

function priceText(quote: LeaderboardQuote | null, side: 'input' | 'output'): string {
  if (!quote) return t('modelLeaderboard.noPrice')
  if (quote.unit !== 'tokens') {
    if (side === 'output') return ''
    return `${formatScaled(quote.unitPrice, 1, 2)} ${t(`modelLeaderboard.units.${quote.unit}`)}`
  }
  const value = side === 'input' ? quote.input : quote.output
  if (value == null) return t('modelLeaderboard.noPrice')
  return `${formatScaled(value, 1, 2)} ${t('modelLeaderboard.units.tokens')}`
}

onMounted(loadLeaderboard)
</script>
