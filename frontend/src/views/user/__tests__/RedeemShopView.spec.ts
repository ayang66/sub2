import { shallowMount } from '@vue/test-utils'
import { describe, expect, it, vi } from 'vitest'

import RedeemShopView from '../RedeemShopView.vue'

vi.mock('vue-i18n', async (importOriginal) => ({
  ...(await importOriginal<typeof import('vue-i18n')>()),
  useI18n: () => ({ t: (key: string) => key }),
}))

describe('RedeemShopView', () => {
  it('embeds the Liandong Shop storefront without user credentials', () => {
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
    expect(frame.attributes('src')).toBe('https://pay.ldxp.cn/shop/XO2MFXMN')
    expect(frame.attributes('src')).not.toContain('token=')
    expect(frame.attributes('src')).not.toContain('user_id=')
  })
})
