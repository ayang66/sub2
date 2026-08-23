<template>
  <div class="flex min-h-[50vh] items-center justify-center p-6">
    <div class="text-center">
      <p class="text-sm text-gray-600 dark:text-gray-300">正在连接 Open WebUI...</p>
      <p v-if="error" class="mt-3 text-sm text-red-500">{{ error }}</p>
      <button v-if="error" class="mt-4 rounded-lg bg-primary-600 px-4 py-2 text-sm text-white" @click="goLogin">返回中转站登录</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()
const error = ref('')

function goLogin() {
  router.replace({ path: '/login', query: { redirect: '/open-webui' } })
}

onMounted(async () => {
  if (!authStore.token) {
    goLogin()
    return
  }
  try {
    const response = await fetch('https://chat.brookeapi.cloud/bridge/session', {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: authStore.token }),
    })
    if (!response.ok) throw new Error('Sub2 登录已失效，请重新登录')
    window.location.href = 'https://chat.brookeapi.cloud/'
  } catch (e) {
    error.value = e instanceof Error ? e.message : '连接 Open WebUI 失败'
  }
})
</script>
