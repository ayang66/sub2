<template>
  <AppLayout>
    <main class="redeem-shop-page">
      <section class="redeem-shop-redirect">
        <Icon name="externalLink" size="xl" class="text-primary-500" />
        <p class="mt-4 text-sm text-gray-600 dark:text-gray-300">
          {{ t('redeemShop.redirecting') }}
        </p>
        <a :href="shopUrl" class="btn btn-primary mt-5">
          <Icon name="externalLink" size="sm" class="mr-1.5" />
          {{ t('redeemShop.openInNewTab') }}
        </a>
      </section>
    </main>
  </AppLayout>
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'

const shopUrl = 'https://pay.ldxp.cn/shop/XO2MFXMN'
const { t } = useI18n()

onMounted(() => {
  window.location.replace(shopUrl)
})
</script>

<style scoped>
.redeem-shop-page {
  display: flex;
  min-height: 0;
  height: calc(100dvh - 64px);
  align-items: center;
  justify-content: center;
  background: rgb(249 250 251);
}

:global(.dark) .redeem-shop-page {
  background: rgb(17 24 39);
}

.redeem-shop-redirect {
  display: flex;
  align-items: center;
  flex-direction: column;
  padding: 32px;
  background: white;
}

@media (max-width: 640px) {
  .redeem-shop-page {
    height: calc(100dvh - 56px);
  }

  .redeem-shop-redirect {
    width: calc(100% - 28px);
    padding: 28px 20px;
  }
}
</style>
