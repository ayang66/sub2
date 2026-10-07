<template>
  <AppLayout>
    <div class="mx-auto max-w-4xl space-y-6">
      <section class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm dark:border-dark-700 dark:bg-dark-900">
        <div class="border-b border-gray-200 bg-gray-50 px-6 py-5 dark:border-dark-700 dark:bg-dark-800/60">
          <div class="flex items-start gap-3">
            <div class="flex h-10 w-10 flex-none items-center justify-center rounded-lg bg-primary-100 text-primary-700 dark:bg-primary-950/50 dark:text-primary-300">
              <Icon name="terminal" size="md" />
            </div>
            <div>
              <h1 class="text-xl font-bold text-gray-900 dark:text-white">Codex 一键配置</h1>
              <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-gray-300">
                连接本机助手后，自动备份并写入 Codex 的两个配置文件。
              </p>
            </div>
          </div>
        </div>

        <div class="space-y-5 p-6">
          <div class="rounded-lg border border-blue-200 bg-blue-50 p-4 text-sm leading-6 text-blue-900 dark:border-blue-900/70 dark:bg-blue-950/30 dark:text-blue-100">
            API Key 和模型名称只在本机助手中处理，不会上传到中转站服务器。先下载并运行助手，再按网站教程模板完成配置。
          </div>

          <div class="rounded-lg border border-gray-200 bg-gray-50 p-4 dark:border-dark-700 dark:bg-dark-800/50">
            <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
              <div>
                <h2 class="font-semibold text-gray-900 dark:text-white">下载并运行本地助手</h2>
                <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-gray-300">
                  下载后直接运行，在助手中输入 API Key 和模型名称即可配置。
                </p>
              </div>
              <div class="flex flex-wrap items-end gap-3">
                <div>
                  <label for="codex-helper-platform" class="input-label mb-1.5 block">选择系统</label>
                  <select id="codex-helper-platform" v-model="selectedDownload" class="input min-w-44">
                    <option v-for="download in downloads" :key="download.value" :value="download.value">{{ download.label }}</option>
                  </select>
                </div>
                <a class="btn btn-secondary whitespace-nowrap" :href="currentDownload.url" download>
                  <Icon name="download" size="sm" />
                  下载助手
                </a>
              </div>
            </div>
            <p class="mt-3 text-xs leading-5 text-gray-500 dark:text-gray-400">Windows 运行 exe；macOS 解压 zip 后双击其中的启动文件。首次运行可能需要确认系统安全提示。</p>
          </div>

          <div class="border-t border-gray-200 pt-5 dark:border-dark-700">
            <div class="rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-sm leading-6 text-emerald-900 dark:border-emerald-900/70 dark:bg-emerald-950/30 dark:text-emerald-100">
              下载并运行助手后，会自动打开本机配置界面。接口地址和配置模板已经内置，默认模型为 gpt-6-astra。
            </div>
          </div>
        </div>
      </section>

      <section class="grid gap-4 md:grid-cols-3">
        <div class="card p-4">
          <Icon name="shield" size="md" class="mb-3 text-emerald-600" />
          <h2 class="font-semibold text-gray-900 dark:text-white">本地传输</h2>
          <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-gray-300">密钥直达 127.0.0.1，不写入网站数据库。</p>
        </div>
        <div class="card p-4">
          <Icon name="inbox" size="md" class="mb-3 text-primary-600" />
          <h2 class="font-semibold text-gray-900 dark:text-white">自动备份</h2>
          <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-gray-300">覆盖前保留带时间戳的旧配置。</p>
        </div>
        <div class="card p-4">
          <Icon name="refresh" size="md" class="mb-3 text-amber-600" />
          <h2 class="font-semibold text-gray-900 dark:text-white">尝试重启</h2>
          <p class="mt-1 text-sm leading-6 text-gray-600 dark:text-gray-300">找不到 Codex 命令时会提示手动重启。</p>
        </div>
      </section>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'

const downloads = [
  { value: 'windows-amd64', label: 'Windows x64', url: '/downloads/codex-setup/codex-local-setup-windows-amd64.exe' },
  { value: 'windows-arm64', label: 'Windows ARM64', url: '/downloads/codex-setup/codex-local-setup-windows-arm64.exe' },
  { value: 'macos-arm64', label: 'macOS Apple 芯片', url: '/downloads/codex-setup/codex-local-setup-macos-arm64.zip' },
  { value: 'macos-amd64', label: 'macOS Intel', url: '/downloads/codex-setup/codex-local-setup-macos-amd64.zip' },
  { value: 'linux-amd64', label: 'Linux x64', url: '/downloads/codex-setup/codex-local-setup-linux-amd64.tar.gz' },
  { value: 'linux-arm64', label: 'Linux ARM64', url: '/downloads/codex-setup/codex-local-setup-linux-arm64.tar.gz' }
]
const selectedDownload = ref(detectDownload())
const currentDownload = computed(() => downloads.find(download => download.value === selectedDownload.value) || downloads[0])

function detectDownload() {
  const platform = navigator.platform.toLowerCase()
  const userAgent = navigator.userAgent.toLowerCase()
  if (platform.includes('win') || userAgent.includes('windows')) return 'windows-amd64'
  if (platform.includes('mac') || userAgent.includes('mac')) return 'macos-arm64'
  if (platform.includes('linux') || userAgent.includes('linux')) return 'linux-amd64'
  return 'windows-amd64'
}

</script>
