<template>
  <AppLayout>
    <div class="mx-auto flex min-h-[calc(100vh-8rem)] max-w-6xl flex-col overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm dark:border-dark-700 dark:bg-dark-900">
      <header class="flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 px-5 py-4 dark:border-dark-700">
        <div>
          <div class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-white"><Icon name="sparkles" size="md" class="text-primary-500" />聊天生图</div>
          <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">普通聊天不会触发生图，输入“画一张/生成图片”才会调用图片模型。</p>
        </div>
        <div class="flex items-center gap-2">
          <select v-model="selectedKeyId" class="input w-48" :disabled="loadingKeys">
            <option value="">选择 API Key</option>
            <option v-for="key in imageKeys" :key="key.id" :value="String(key.id)">{{ key.name || `${key.key.slice(0, 10)}...` }}</option>
          </select>
          <select v-model="imageModel" class="input w-40">
            <option v-for="model in imageModels" :key="model" :value="model">{{ model }}</option>
          </select>
        </div>
      </header>

      <main ref="messageList" class="flex-1 space-y-6 overflow-y-auto p-5 md:p-8">
        <div v-if="messages.length === 0" class="flex min-h-[360px] flex-col items-center justify-center text-center">
          <div class="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary-50 text-primary-600 dark:bg-primary-900/30 dark:text-primary-300"><Icon name="sparkles" size="xl" /></div>
          <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">你想创作什么？</h1>
          <p class="mt-2 max-w-md text-sm leading-6 text-gray-500 dark:text-gray-400">可以直接聊天，也可以说“生成一张复古海报”。系统会根据你的意图选择文字或图片模型。</p>
        </div>
        <article v-for="message in messages" :key="message.id" class="flex gap-3" :class="message.role === 'user' ? 'justify-end' : 'justify-start'">
          <div class="max-w-3xl" :class="message.role === 'user' ? 'order-first' : ''">
            <div class="rounded-2xl px-4 py-3 text-sm leading-7" :class="message.role === 'user' ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-800 dark:bg-dark-800 dark:text-gray-100'">
              <p v-if="message.text" class="whitespace-pre-wrap">{{ message.text }}</p>
              <img v-if="message.referenceUrl" :src="message.referenceUrl" alt="参考图" class="mt-3 max-h-48 rounded-lg object-contain" />
              <div v-if="message.imageUrl" class="mt-3 overflow-hidden rounded-xl bg-black/5">
                <img :src="message.imageUrl" alt="生成的图片" class="max-h-[560px] w-full object-contain" />
                <div class="flex flex-wrap gap-2 p-2">
                  <a :href="message.imageUrl" download="hakimi-generated-image.png" class="btn btn-secondary btn-sm"><Icon name="download" size="sm" class="mr-1" />下载图片</a>
                  <button type="button" class="btn btn-secondary btn-sm" @click="startBranch(message)"><Icon name="sparkles" size="sm" class="mr-1" />从此处继续</button>
                </div>
              </div>
            </div>
            <p v-if="message.error" class="mt-2 text-xs text-red-600 dark:text-red-400">{{ message.error }}</p>
          </div>
        </article>
        <div v-if="generating" class="flex items-center gap-2 text-sm text-gray-500"><Icon name="refresh" size="sm" class="animate-spin" />正在处理...</div>
      </main>

      <footer class="border-t border-gray-200 p-4 dark:border-dark-700 md:p-5">
        <div v-if="branchPrompt" class="mb-3 flex items-center justify-between rounded-lg bg-primary-50 px-3 py-2 text-sm text-primary-700 dark:bg-primary-900/20 dark:text-primary-200"><span>正在从图片分支继续创作</span><button type="button" class="text-xs underline" @click="branchPrompt = ''">取消</button></div>
        <div v-if="referencePreview" class="mb-3 flex items-center gap-3 rounded-lg border border-gray-200 bg-gray-50 p-2 dark:border-dark-700 dark:bg-dark-800">
          <img :src="referencePreview" alt="已选择的参考图" class="h-16 w-16 rounded object-cover" />
          <span class="min-w-0 flex-1 truncate text-sm text-gray-600 dark:text-gray-300">{{ referenceFile?.name }}</span>
          <button type="button" class="btn btn-secondary btn-sm" @click="clearReference()">移除</button>
        </div>
        <div class="flex items-end gap-3 rounded-2xl border border-gray-300 bg-gray-50 p-2 focus-within:border-primary-500 dark:border-dark-600 dark:bg-dark-800">
          <input ref="fileInput" type="file" accept="image/png,image/jpeg,image/webp" class="hidden" @change="onReferenceSelected" />
          <button type="button" class="btn btn-secondary h-11 w-11 p-0" title="上传参考图" :disabled="generating" @click="fileInput?.click()"><Icon name="upload" size="md" /></button>
          <textarea v-model="prompt" rows="2" class="min-h-[48px] flex-1 resize-none border-0 bg-transparent px-2 py-2 text-sm outline-none placeholder:text-gray-400 dark:text-white" placeholder="输入消息，或描述你想生成的图片..." @keydown.enter.exact.prevent="submit" @paste="onPaste" />
          <button type="button" class="btn btn-primary h-11 w-11 p-0" :disabled="generating || !prompt.trim() || !selectedKey" title="发送" @click="submit"><Icon name="arrowUp" size="md" /></button>
        </div>
        <p v-if="!selectedKey" class="mt-2 text-xs text-amber-600 dark:text-amber-400">请先选择一个允许生图的活动 API Key。</p>
      </footer>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, ref } from 'vue'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'
import { keysAPI } from '@/api'
import { editImage, extractResponseText, generateImage, sendChatMessage } from '@/api/imageGeneration'
import type { ApiKey } from '@/types'
import { useAppStore } from '@/stores'

interface Message { id: number; role: 'user' | 'assistant'; text?: string; imageUrl?: string; referenceUrl?: string; error?: string }
const appStore = useAppStore()
const keys = ref<ApiKey[]>([])
const selectedKeyId = ref('')
const imageModel = ref('gpt-image-2')
const prompt = ref('')
const branchPrompt = ref('')
const messages = ref<Message[]>([])
const generating = ref(false)
const loadingKeys = ref(false)
const messageList = ref<HTMLElement | null>(null)
const fileInput = ref<HTMLInputElement | null>(null)
const referenceFile = ref<File | null>(null)
const referencePreview = ref('')
const imageModels = ['gpt-image-2', 'dall-e-3', 'image2']
const imageKeys = computed(() => keys.value.filter(key => key.status === 'active' && key.group?.allow_image_generation === true))
const selectedKey = computed(() => imageKeys.value.find(key => String(key.id) === selectedKeyId.value) || imageKeys.value[0])

async function loadKeys() {
  loadingKeys.value = true
  try {
    const response = await keysAPI.list(1, 100, { status: 'active', sort_by: 'created_at', sort_order: 'desc' })
    keys.value = response.items || []
    if (!selectedKeyId.value && imageKeys.value[0]) selectedKeyId.value = String(imageKeys.value[0].id)
  } catch (error) {
    appStore.showError(error instanceof Error ? error.message : '加载 API Key 失败')
  } finally { loadingKeys.value = false }
}

function looksLikeImageRequest(text: string) {
  return /生成.*图|生图|画一张|画个|绘制|海报|头像|插画|图片|照片|场景|logo|封面|改成.*风格|重新生成/i.test(text)
}

function dataUrl(item: { b64_json?: string; url?: string }) {
  return item.b64_json ? `data:image/png;base64,${item.b64_json}` : item.url || ''
}

function setReference(file: File) {
  if (file.size > 20 * 1024 * 1024) {
    appStore.showError('参考图不能超过 20MB')
    return
  }
  if (referencePreview.value) URL.revokeObjectURL(referencePreview.value)
  referenceFile.value = file
  referencePreview.value = URL.createObjectURL(file)
}

function onReferenceSelected(event: Event) {
  const file = (event.target as HTMLInputElement).files?.[0]
  if (file) setReference(file)
}

function onPaste(event: ClipboardEvent) {
  const image = Array.from(event.clipboardData?.items || [])
    .find(item => item.kind === 'file' && item.type.startsWith('image/'))
    ?.getAsFile()
  if (!image) return
  event.preventDefault()
  setReference(image)
}

function clearReference(revoke = true) {
  if (revoke && referencePreview.value) URL.revokeObjectURL(referencePreview.value)
  referenceFile.value = null
  referencePreview.value = ''
  if (fileInput.value) fileInput.value.value = ''
}

async function submit() {
  const text = prompt.value.trim(); if (!text || generating.value || !selectedKey.value) return
  const currentReference = referenceFile.value
  const currentReferenceUrl = referencePreview.value
  prompt.value = ''; messages.value.push({ id: Date.now(), role: 'user', text, referenceUrl: currentReferenceUrl || undefined })
  clearReference(false)
  generating.value = true
  try {
    if (currentReference || looksLikeImageRequest(`${branchPrompt.value} ${text}`)) {
      const result = currentReference
        ? await editImage(selectedKey.value.key, currentReference, { model: imageModel.value, prompt: `${branchPrompt.value} ${text}`.trim(), size: '1024x1024', response_format: 'b64_json' })
        : await generateImage(selectedKey.value.key, { model: imageModel.value, prompt: `${branchPrompt.value} ${text}`.trim(), size: '1024x1024', n: 1, response_format: 'b64_json' })
      const imageUrl = dataUrl(result.data?.[0] || {})
      messages.value.push({ id: Date.now() + 1, role: 'assistant', text: imageUrl ? '图片生成完成。' : '上游没有返回图片结果。', imageUrl })
      branchPrompt.value = ''
    } else {
      const result = await sendChatMessage(selectedKey.value.key, 'gpt-5.5', text)
      messages.value.push({ id: Date.now() + 1, role: 'assistant', text: extractResponseText(result) })
    }
  } catch (error) {
    messages.value.push({ id: Date.now() + 1, role: 'assistant', text: '这次请求没有完成。', error: error instanceof Error ? error.message : '请求失败' })
  } finally { generating.value = false; await nextTick(); messageList.value?.scrollTo({ top: messageList.value.scrollHeight, behavior: 'smooth' }) }
}

function startBranch(_message?: Message) { branchPrompt.value = '基于刚才这张图片继续修改：'; prompt.value = ''; }
onMounted(loadKeys)
</script>
