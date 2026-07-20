<template>
  <AppLayout>
    <main class="redeem-shop-page">
      <header class="redeem-shop-toolbar">
        <div class="min-w-0">
          <h1 class="text-lg font-semibold text-gray-900 dark:text-white">
            {{ t('redeemShop.title') }}
          </h1>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
            {{ t('redeemShop.description') }}
          </p>
        </div>
        <div class="flex flex-none items-center gap-2">
          <router-link to="/redeem" class="btn btn-primary btn-sm">
            <Icon name="gift" size="sm" class="mr-1.5" />
            {{ t('redeemShop.redeemNow') }}
          </router-link>
          <a
            :href="shopUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="btn btn-secondary btn-sm"
          >
            <Icon name="externalLink" size="sm" class="mr-1.5" />
            {{ t('redeemShop.openInNewTab') }}
          </a>
        </div>
      </header>

      <section class="redeem-shop-frame-shell">
        <div v-if="loading" class="redeem-shop-loading">
          <Icon name="refresh" size="lg" class="animate-spin text-primary-500" />
        </div>
        <iframe
          :src="shopUrl"
          :title="t('redeemShop.iframeTitle')"
          class="redeem-shop-frame"
          referrerpolicy="strict-origin-when-cross-origin"
          allow="payment *; clipboard-write"
          @load="loading = false"
        ></iframe>
      </section>
    </main>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'

const shopUrl = 'https://pay.ldxp.cn/shop/XO2MFXMN'
const loading = ref(true)
const { t } = useI18n()
</script>

<style scoped>
.redeem-shop-page {
  display: flex;
  min-height: 0;
  height: calc(100dvh - 64px);
  flex-direction: column;
  background: rgb(249 250 251);
}

:global(.dark) .redeem-shop-page {
  background: rgb(17 24 39);
}

.redeem-shop-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid rgb(229 231 235);
  background: white;
  padding: 14px 20px;
}

:global(.dark) .redeem-shop-toolbar {
  border-color: rgb(55 65 81);
  background: rgb(31 41 55);
}

.redeem-shop-frame-shell {
  position: relative;
  min-height: 0;
  flex: 1;
  overflow: hidden;
  background: white;
}

.redeem-shop-loading {
  position: absolute;
  inset: 0;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgb(249 250 251);
}

.redeem-shop-frame {
  display: block;
  width: 100%;
  height: 100%;
  min-height: 620px;
  border: 0;
  background: white;
}

@media (max-width: 640px) {
  .redeem-shop-page {
    height: calc(100dvh - 56px);
  }

  .redeem-shop-toolbar {
    align-items: flex-start;
    flex-direction: column;
    padding: 12px 14px;
  }

  .redeem-shop-toolbar > div:last-child {
    width: 100%;
  }

  .redeem-shop-toolbar .btn {
    flex: 1;
  }
}
</style>
