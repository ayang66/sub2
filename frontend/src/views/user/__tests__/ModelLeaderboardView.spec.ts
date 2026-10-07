import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'

import ModelLeaderboardView from '../ModelLeaderboardView.vue'

const { getAvailable, getUserGroupRates } = vi.hoisted(() => ({
  getAvailable: vi.fn(),
  getUserGroupRates: vi.fn(),
}))

vi.mock('@/api/channels', () => ({
  default: { getAvailable },
}))

vi.mock('@/api/groups', () => ({
  default: { getUserGroupRates },
}))

vi.mock('@/stores/app', () => ({
  useAppStore: () => ({ showError: vi.fn() }),
}))

vi.mock('vue-i18n', async () => {
  const actual = await vi.importActual<typeof import('vue-i18n')>('vue-i18n')
  return {
    ...actual,
    useI18n: () => ({
      t: (key: string, params?: { count?: number }) =>
        key === 'modelLeaderboard.moreGroups' ? `+${params?.count}` : key,
    }),
  }
})

const pricing = {
  billing_mode: 'token',
  input_price: 0.000002,
  output_price: 0.000006,
  cache_write_price: null,
  cache_read_price: null,
  image_input_price: null,
  image_output_price: null,
  per_request_price: null,
  intervals: [],
}

function group(id: number, name: string, rate: number) {
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
  }
}

describe('ModelLeaderboardView', () => {
  it('shows the cheapest group price and can rerank by price', async () => {
    getAvailable.mockResolvedValue([
      {
        name: 'OpenAI',
        description: '',
        platforms: [{
          platform: 'openai',
          groups: [group(2, 'Codex Pro', 0.12), group(3, 'Codex Plus', 0.1)],
          supported_models: [
            { name: 'gpt-6-astra', platform: 'openai', pricing },
            { name: 'claude-haiku-4-5', platform: 'anthropic', pricing },
          ],
        }],
      },
    ])
    getUserGroupRates.mockResolvedValue({})

    const wrapper = mount(ModelLeaderboardView, {
      global: {
        stubs: {
          AppLayout: { template: '<div><slot /></div>' },
          Icon: true,
          PlatformIcon: true,
        },
      },
    })
    await flushPromises()

    const models = wrapper.findAll('[data-model]').map((row) => row.attributes('data-model'))
    expect(models).toEqual(['gpt-6-astra', 'claude-haiku-4-5'])
    expect(wrapper.get('[data-model="gpt-6-astra"]').text()).toContain('Codex Plus')
    expect(wrapper.get('[data-model="gpt-6-astra"]').text()).toContain('$0.20')

    const buttons = wrapper.findAll('button')
    await buttons.find((button) => button.text() === 'modelLeaderboard.sortPrice')!.trigger('click')

    const priceOrder = wrapper.findAll('[data-model]').map((row) => row.attributes('data-model'))
    expect(priceOrder).toEqual(['claude-haiku-4-5', 'gpt-6-astra'])
  })
})
