<template>
  <AppLayout>
    <div class="mx-auto max-w-6xl space-y-6">
      <section class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm dark:border-dark-700 dark:bg-dark-900">
        <div class="grid gap-8 p-6 lg:grid-cols-[1.25fr_0.75fr] lg:items-center lg:p-8">
          <div>
            <div class="mb-4 inline-flex items-center gap-2 text-sm font-semibold text-primary-600 dark:text-primary-400">
              <BoltIcon class="h-4 w-4" />
              Windows 桌面安装器
            </div>
            <h1 class="text-2xl font-bold text-gray-900 dark:text-white md:text-3xl">AI 编程工具一键安装</h1>
            <p class="mt-3 max-w-3xl text-sm leading-7 text-gray-600 dark:text-gray-300">
              为普通用户集中提供 Codex、Claude Code 和 CC Switch 的可信下载入口，并附带哈基米中转站所需的完整模型配置。
            </p>
            <div class="mt-6 flex flex-wrap gap-3">
              <a :href="CODEX_MSI_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-primary">
                <DownloadIcon class="h-4 w-4" />一键安装 Codex
              </a>
              <a :href="CLAUDE_INSTALLER_ZIP_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-secondary">
                <DownloadIcon class="h-4 w-4" />下载 Claude Code 安装工具
              </a>
              <a :href="CCSWITCH_MSI_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-secondary">
                <DownloadIcon class="h-4 w-4" />下载 CC Switch
              </a>
              <router-link to="/guide" class="tool-button tool-button-quiet">
                <DocumentIcon class="h-4 w-4" />查看配置文档
              </router-link>
            </div>
          </div>

          <div class="space-y-3 rounded-lg border border-gray-200 bg-gray-50 p-4 dark:border-dark-700 dark:bg-dark-800">
            <InfoRow label="Codex 接口基址" :value="openAiBaseUrl" />
            <InfoRow label="Claude Code 基址" :value="anthropicBaseUrl" />
            <InfoRow label="默认模型" value="gpt-5.5" />
            <InfoRow label="客服微信" value="15137315710" copyable />
          </div>
        </div>
      </section>

      <section class="grid gap-4 md:grid-cols-3">
        <FeatureCard title="自动下载并安装" description="Codex 安装器从 agentsmirror 的 Windows x64 地址获取 MSI，减少手动选择步骤。">
          <DownloadIcon class="h-5 w-5" />
        </FeatureCard>
        <FeatureCard title="支持自定义目录" description="默认安装到 D:\DevSoftWareTest\codex，安装前会自动创建目录，也可以改成自己的路径。">
          <DesktopIcon class="h-5 w-5" />
        </FeatureCard>
        <FeatureCard title="写入模型配置" description="支持填写模型供应商、Base URL、SK 密钥和模型名称，生成 Codex 所需配置。">
          <CogIcon class="h-5 w-5" />
        </FeatureCard>
      </section>

      <ToolSection title="Codex 配置" description="安装后将下面两个文件写入用户的 .codex 配置目录。">
        <div class="grid gap-4 lg:grid-cols-2">
          <CodeBlock title="auth.json" :code="authJson" />
          <CodeBlock title="config.toml" :code="codexConfig" />
        </div>
      </ToolSection>

      <ToolSection title="Claude Code 一键安装" description="使用开源项目 lxistired/claude-code-cn-installer，自动检查 Node.js、Git 和 Claude Code。">
        <div class="grid gap-5 lg:grid-cols-[0.9fr_1.1fr]">
          <div class="space-y-3">
            <InfoRow label="系统要求" value="Windows 10 或更高版本" />
            <InfoRow label="接口基址" :value="anthropicBaseUrl" />
            <InfoRow label="请求接口" value="/v1/messages" />
            <InfoRow label="Opus 模型" value="claude-opus-4-7" />
            <InfoRow label="Sonnet 模型" value="claude-sonnet-4-6" />
          </div>
          <div class="rounded-lg border border-gray-200 p-5 dark:border-dark-700">
            <h3 class="font-semibold text-gray-900 dark:text-white">安装步骤</h3>
            <ol class="mt-3 list-decimal space-y-2 pl-5 text-sm leading-6 text-gray-600 dark:text-gray-300">
              <li>下载并解压项目 ZIP，以管理员身份运行“一键安装.bat”。</li>
              <li>安装脚本询问智谱模型时选择“暂时跳过”。</li>
              <li>运行“配置API.bat”，选择菜单 4“自定义 Anthropic 兼容 API”。</li>
              <li>填写本站 Base URL、自己的 API Key 和页面推荐的模型名称。</li>
            </ol>
            <div class="mt-5 flex flex-wrap gap-3">
              <a :href="CLAUDE_INSTALLER_ZIP_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-primary">下载项目 ZIP</a>
              <a :href="CLAUDE_INSTALLER_REPO_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-quiet">查看原项目</a>
            </div>
          </div>
        </div>
        <div class="mt-5">
          <CodeBlock title=".claude/settings.json" :code="claudeConfig" />
        </div>
      </ToolSection>

      <ToolSection title="CC Switch" description="用于统一管理 Codex、Claude Code、Gemini CLI 等开发工具配置，下载地址来自官方 GitHub Release。">
        <div class="grid gap-5 lg:grid-cols-2">
          <div class="space-y-3">
            <InfoRow label="官方主页" value="https://ccswitch.io" />
            <InfoRow label="官方仓库" value="farion1231/cc-switch" />
            <InfoRow label="Windows 安装包" value="CC-Switch-v3.16.5-Windows.msi" />
          </div>
          <div class="flex flex-col justify-between gap-5 rounded-lg border border-gray-200 p-5 dark:border-dark-700">
            <p class="text-sm leading-6 text-gray-600 dark:text-gray-300">建议小白用户先安装 Codex，再通过 CC Switch 管理本站 API Key 和模型配置。</p>
            <div class="flex flex-wrap gap-3">
              <a :href="CCSWITCH_MSI_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-primary">下载 CC Switch MSI</a>
              <a :href="CCSWITCH_RELEASE_URL" target="_blank" rel="noreferrer" class="tool-button tool-button-quiet">查看官方 Release</a>
            </div>
          </div>
        </div>
      </ToolSection>

      <div class="rounded-lg border border-amber-200 bg-amber-50 p-5 text-sm leading-6 text-amber-950 dark:border-amber-900 dark:bg-amber-950/30 dark:text-amber-100">
        Claude Code 必须使用支持 <code>/v1/messages</code> 的分组和模型。安装或配置遇到问题，可添加客服微信
        <button type="button" class="font-semibold underline decoration-dotted underline-offset-4" @click="copyWechat">15137315710</button>，新客领五元额度。
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, defineComponent, h } from 'vue'
import AppLayout from '@/components/layout/AppLayout.vue'
import { useAppStore } from '@/stores'

const CODEX_MSI_URL = 'https://codexapp.agentsmirror.com/latest/win-x64'
const CCSWITCH_MSI_URL = 'https://github.com/farion1231/cc-switch/releases/download/v3.16.5/CC-Switch-v3.16.5-Windows.msi'
const CCSWITCH_RELEASE_URL = 'https://github.com/farion1231/cc-switch/releases/tag/v3.16.5'
const CLAUDE_INSTALLER_REPO_URL = 'https://github.com/lxistired/claude-code-cn-installer'
const CLAUDE_INSTALLER_ZIP_URL = 'https://github.com/lxistired/claude-code-cn-installer/archive/refs/heads/main.zip'

const appStore = useAppStore()
const anthropicBaseUrl = computed(() => window.location.origin)
const openAiBaseUrl = computed(() => `${anthropicBaseUrl.value}/v1`)

const authJson = `{
  "OPENAI_API_KEY": "sk-xxx"
}`

const codexConfig = computed(() => `cli_auth_credentials_store = "file"

disable_response_storage = true
model = "gpt-5.5"
model_provider = "hakimi"
model_reasoning_effort = "xhigh"
personality = "friendly"

[model_providers.hakimi]
name = "hakimi"
base_url = "${openAiBaseUrl.value}"
requires_openai_auth = true
wire_api = "responses"`)

const claudeConfig = computed(() => `{
  "env": {
    "ANTHROPIC_BASE_URL": "${anthropicBaseUrl.value}",
    "ANTHROPIC_API_KEY": "sk-xxx",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-sonnet-4-6"
  }
}`)

async function copyText(value: string) {
  try {
    await navigator.clipboard.writeText(value)
    appStore.showSuccess('已复制')
  } catch {
    appStore.showError('复制失败，请手动复制')
  }
}

function copyWechat() {
  void copyText('15137315710')
}

const InfoRow = defineComponent({
  props: { label: { type: String, required: true }, value: { type: String, required: true }, copyable: Boolean },
  setup(props) {
    return () => h('div', { class: 'flex min-w-0 flex-col gap-1 rounded-lg border border-gray-200 bg-white px-4 py-3 dark:border-dark-700 dark:bg-dark-900 sm:flex-row sm:items-center sm:justify-between' }, [
      h('span', { class: 'text-sm font-medium text-gray-500 dark:text-gray-400' }, props.label),
      h(props.copyable ? 'button' : 'code', { class: 'break-all text-left text-sm text-gray-900 dark:text-gray-100 sm:text-right', onClick: props.copyable ? () => copyText(props.value) : undefined, title: props.copyable ? '点击复制' : undefined }, props.value)
    ])
  }
})

const FeatureCard = defineComponent({
  props: { title: { type: String, required: true }, description: { type: String, required: true } },
  setup(props, { slots }) {
    return () => h('div', { class: 'rounded-lg border border-gray-200 bg-white p-5 shadow-sm dark:border-dark-700 dark:bg-dark-900' }, [
      h('div', { class: 'mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-primary-50 text-primary-600 dark:bg-primary-950/50 dark:text-primary-400' }, slots.default?.()),
      h('h3', { class: 'font-semibold text-gray-900 dark:text-white' }, props.title),
      h('p', { class: 'mt-2 text-sm leading-6 text-gray-600 dark:text-gray-300' }, props.description)
    ])
  }
})

const ToolSection = defineComponent({
  props: { title: { type: String, required: true }, description: { type: String, required: true } },
  setup(props, { slots }) {
    return () => h('section', { class: 'rounded-lg border border-gray-200 bg-white p-6 shadow-sm dark:border-dark-700 dark:bg-dark-900' }, [
      h('h2', { class: 'text-xl font-semibold text-gray-900 dark:text-white' }, props.title),
      h('p', { class: 'mb-5 mt-2 text-sm leading-6 text-gray-600 dark:text-gray-300' }, props.description),
      slots.default?.()
    ])
  }
})

const CodeBlock = defineComponent({
  props: { title: { type: String, required: true }, code: { type: String, required: true } },
  setup(props) {
    return () => h('div', { class: 'overflow-hidden rounded-lg border border-gray-200 dark:border-dark-700' }, [
      h('div', { class: 'flex items-center justify-between border-b border-gray-200 bg-gray-50 px-4 py-2 dark:border-dark-700 dark:bg-dark-800' }, [
        h('span', { class: 'text-sm font-semibold text-gray-700 dark:text-gray-200' }, props.title),
        h('button', { class: 'text-xs font-medium text-primary-600 hover:text-primary-700 dark:text-primary-400', onClick: () => copyText(props.code) }, '复制')
      ]),
      h('pre', { class: 'm-0 overflow-x-auto bg-gray-950 p-4 text-sm leading-6 text-gray-100' }, h('code', props.code))
    ])
  }
})

const svgIcon = (paths: string[]) => defineComponent({
  setup() {
    return () => h('svg', { fill: 'none', viewBox: '0 0 24 24', stroke: 'currentColor', 'stroke-width': '1.5' }, paths.map(d => h('path', { 'stroke-linecap': 'round', 'stroke-linejoin': 'round', d })))
  }
})

const DownloadIcon = svgIcon(['M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M7.5 10.5L12 15m0 0l4.5-4.5M12 15V3'])
const DesktopIcon = svgIcon(['M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 4h14a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V6a2 2 0 012-2z'])
const CogIcon = svgIcon(['M10.5 6h3m-6.75 4.5h10.5m-9 4.5h7.5M5.25 3.75h13.5A2.25 2.25 0 0121 6v12a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18V6a2.25 2.25 0 012.25-2.25z'])
const BoltIcon = svgIcon(['m13.5 2.25-8.25 11.25h7.5l-2.25 8.25 8.25-11.25h-7.5l2.25-8.25z'])
const DocumentIcon = svgIcon(['M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25M8.25 12h7.5m-7.5 3h7.5m-7.5 3H12M10.5 2.25H5.625A1.125 1.125 0 004.5 3.375v17.25c0 .621.504 1.125 1.125 1.125h12.75a1.125 1.125 0 001.125-1.125V11.25a9 9 0 00-9-9z'])
</script>

<style scoped>
.tool-button { @apply inline-flex min-h-10 items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-semibold transition-colors; }
.tool-button-primary { @apply bg-primary-600 text-white hover:bg-primary-700; }
.tool-button-secondary { @apply border border-primary-200 bg-primary-50 text-primary-700 hover:bg-primary-100 dark:border-primary-900 dark:bg-primary-950/40 dark:text-primary-300 dark:hover:bg-primary-950/70; }
.tool-button-quiet { @apply border border-gray-200 bg-white text-gray-700 hover:bg-gray-50 dark:border-dark-600 dark:bg-dark-800 dark:text-gray-200 dark:hover:bg-dark-700; }
</style>
