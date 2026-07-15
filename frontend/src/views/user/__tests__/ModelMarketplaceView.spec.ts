import { flushPromises, mount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'

import ModelMarketplaceView from '../ModelMarketplaceView.vue'

const { getAvailable, getUserGroupRates, listMonitors } = vi.hoisted(() => ({
  getAvailable: vi.fn(),
  getUserGroupRates: vi.fn(),
  listMonitors: vi.fn(),
}))

vi.mock('@/api/channels', () => ({
  default: { getAvailable },
}))

vi.mock('@/api/groups', () => ({
  default: { getUserGroupRates },
}))

vi.mock('@/api/channelMonitor', () => ({
  default: { list: listMonitors },
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
        key === 'modelMarketplace.availableGroups' ? `${params?.count} groups` : key,
    }),
  }
})

const groupA = {
  id: 101,
  name: 'Elucid / codex-pro',
  platform: 'openai',
  subscription_type: 'standard',
  rate_multiplier: 0.12,
  peak_rate_enabled: false,
  peak_start: '',
  peak_end: '',
  peak_rate_multiplier: 1,
  is_exclusive: false,
}

const groupB = {
  ...groupA,
  id: 102,
  name: 'Elucid / codex-mixed',
  rate_multiplier: 0.06,
}

const groupTeam = {
  ...groupA,
  id: 103,
  name: 'Codex Team',
  rate_multiplier: 0.05,
}

const pricing = {
  billing_mode: 'token',
  input_price: 0.000005,
  output_price: 0.00003,
  cache_write_price: null,
  cache_read_price: null,
  image_output_price: null,
  per_request_price: null,
  intervals: [],
}

function mountView() {
  getAvailable.mockResolvedValue([
    {
      name: 'Elucid / codex-pro',
      description: '',
      platforms: [{
        platform: 'openai',
        groups: [groupA],
        supported_models: [
          { name: 'gpt-5.5', platform: 'openai', pricing },
          { name: 'gpt-5.6', platform: 'openai', pricing },
        ],
      }],
    },
    {
      name: 'Elucid / codex-mixed',
      description: '',
      platforms: [{
        platform: 'openai',
        groups: [groupB],
        supported_models: [{ name: 'gpt-5.5', platform: 'openai', pricing }],
      }],
    },
    {
      name: 'Codex Team',
      description: '',
      platforms: [{
        platform: 'openai',
        groups: [groupTeam],
        supported_models: [{ name: 'gpt-5.5', platform: 'openai', pricing }],
      }],
    },
    {
      name: 'Elucid / cn-openai',
      description: '',
      platforms: [{
        platform: 'openai',
        groups: [{ ...groupA, id: 104, name: 'Elucid / cn-openai', rate_multiplier: 0.48 }],
        supported_models: [{ name: 'deepseek-v4-pro', platform: 'openai', pricing }],
      }],
    },
  ])
  getUserGroupRates.mockResolvedValue({})
  listMonitors.mockResolvedValue({ items: [] })

  return mount(ModelMarketplaceView, {
    global: {
      stubs: {
        AppLayout: { template: '<div><slot /></div>' },
        BaseDialog: true,
        Icon: true,
        PlatformIcon: true,
      },
    },
  })
}

describe('ModelMarketplaceView filters', () => {
  it('pins GPT models and marks Codex Team as recommended', async () => {
    const wrapper = mountView()
    await flushPromises()

    const cards = wrapper.findAll('article')
    expect(cards[0].attributes('data-model')).toBe('gpt-5.5')
    expect(cards[1].attributes('data-model')).toBe('gpt-5.6')
    expect(cards.at(-1)?.attributes('data-model')).toBe('deepseek-v4-pro')
    expect(wrapper.get('[data-test="recommended-offer"]').text()).toBe('modelMarketplace.recommended')
  })

  it('removes offers from other groups when a group is selected', async () => {
    const wrapper = mountView()
    await flushPromises()

    const selects = wrapper.findAll('select')
    await selects[2].setValue(String(groupA.id))

    const results = wrapper.findAll('article').map((article) => article.text()).join('\n')
    expect(results).toContain('Elucid / codex-pro')
    expect(results).not.toContain('Elucid / codex-mixed')
    expect(results).toContain('gpt-5.6')
  })

  it('shows only the matching offer when searching by group name', async () => {
    const wrapper = mountView()
    await flushPromises()

    await wrapper.get('input').setValue('codex-mixed')

    const results = wrapper.findAll('article').map((article) => article.text()).join('\n')
    expect(results).toContain('Elucid / codex-mixed')
    expect(results).not.toContain('Elucid / codex-pro')
    expect(results).not.toContain('gpt-5.6')
  })
})
