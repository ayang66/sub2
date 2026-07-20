import { shallowMount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'

import RedeemShopView from '../RedeemShopView.vue'

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (key: string) => key }),
}))

describe('RedeemShopView', () => {
  it('embeds the fixed Liandong Shop product without user credentials', () => {
    const wrapper = shallowMount(RedeemShopView, {
      global: {
        stubs: {
          AppLayout: { template: '<div><slot /></div>' },
          Icon: true,
          RouterLink: true,
        },
      },
    })

    const frame = wrapper.get('iframe')
    expect(frame.attributes('src')).toBe('https://pay.ldxp.cn/item/36093g')
    expect(frame.attributes('src')).not.toContain('token=')
    expect(frame.attributes('src')).not.toContain('user_id=')
  })
})
