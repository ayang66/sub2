<template>
  <div class="min-h-screen bg-gray-50 dark:bg-dark-950">
    <!-- Background Decoration -->
    <div class="pointer-events-none fixed inset-0 bg-mesh-gradient"></div>

    <!-- Sidebar -->
    <AppSidebar />

    <!-- Main Content Area -->
    <div
      class="relative min-h-screen transition-all duration-300"
      :class="[sidebarCollapsed ? 'lg:ml-[72px]' : 'lg:ml-64']"
    >
      <!-- Header -->
      <AppHeader />

      <div
        v-if="contactInfo"
        class="border-b border-emerald-200 bg-emerald-50 px-4 py-2 dark:border-emerald-900/70 dark:bg-emerald-950/40 md:px-6"
      >
        <button
          type="button"
          class="mx-auto flex w-full max-w-5xl flex-wrap items-center justify-center gap-2 text-sm text-emerald-900 dark:text-emerald-100"
          aria-label="复制客服微信"
          @click="copySupportWechat"
        >
          <Icon name="chatBubble" size="sm" class="shrink-0 text-emerald-600 dark:text-emerald-400" />
          <span class="font-medium">客服微信</span>
          <strong class="text-base">{{ supportWechat }}</strong>
          <Icon :name="supportCopied ? 'check' : 'copy'" size="sm" class="shrink-0" />
        </button>
      </div>

      <!-- Main Content -->
      <main class="p-4 md:p-6 lg:p-8">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import '@/styles/onboarding.css'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useAppStore } from '@/stores'
import { useAuthStore } from '@/stores/auth'
import { useOnboardingTour } from '@/composables/useOnboardingTour'
import { useOnboardingStore } from '@/stores/onboarding'
import { useClipboard } from '@/composables/useClipboard'
import AppSidebar from './AppSidebar.vue'
import AppHeader from './AppHeader.vue'
import Icon from '@/components/icons/Icon.vue'

const appStore = useAppStore()
const authStore = useAuthStore()
const sidebarCollapsed = computed(() => appStore.sidebarCollapsed)
const isAdmin = computed(() => authStore.user?.role === 'admin')
const contactInfo = computed(() => appStore.contactInfo)
const supportWechat = computed(() => contactInfo.value.match(/\d{6,}/)?.[0] || contactInfo.value)
const supportCopied = ref(false)
const { copyToClipboard } = useClipboard()
let supportCopyTimer: number | undefined

async function copySupportWechat() {
  const copied = await copyToClipboard(supportWechat.value, '客服微信已复制')
  if (!copied) return
  supportCopied.value = true
  if (supportCopyTimer !== undefined) window.clearTimeout(supportCopyTimer)
  supportCopyTimer = window.setTimeout(() => {
    supportCopied.value = false
  }, 1800)
}

const { replayTour } = useOnboardingTour({
  storageKey: isAdmin.value ? 'admin_guide' : 'user_guide',
  autoStart: true
})

const onboardingStore = useOnboardingStore()

onMounted(() => {
  onboardingStore.setReplayCallback(replayTour)
})

onBeforeUnmount(() => {
  if (supportCopyTimer !== undefined) window.clearTimeout(supportCopyTimer)
})

defineExpose({ replayTour })
</script>
