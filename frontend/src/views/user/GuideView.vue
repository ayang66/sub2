<template>
  <AppLayout>
    <div class="mx-auto max-w-6xl">
      <div class="grid gap-6 lg:grid-cols-[220px_minmax(0,1fr)]">
        <aside class="hidden lg:block">
          <div class="sticky top-24 rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-dark-700 dark:bg-dark-900">
            <div class="mb-3 text-sm font-semibold text-gray-900 dark:text-white">文档目录</div>
            <nav class="space-y-1">
              <a v-for="heading in headings" :key="heading.id" :href="`#${heading.id}`" class="block rounded px-2 py-1.5 text-sm text-gray-600 hover:bg-gray-50 hover:text-primary-600 dark:text-gray-300 dark:hover:bg-dark-800 dark:hover:text-primary-400">
                {{ heading.text }}
              </a>
            </nav>
          </div>
        </aside>

        <article class="min-w-0 rounded-lg border border-gray-200 bg-white p-5 shadow-sm dark:border-dark-700 dark:bg-dark-900 md:p-8">
          <div class="mb-7 flex flex-wrap items-center justify-between gap-3 border-b border-gray-200 pb-5 dark:border-dark-700">
            <div>
              <div class="text-sm font-semibold text-primary-600 dark:text-primary-400">哈基米中转站</div>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Codex、Claude Code 与 CC Switch 完整接入指南</p>
            </div>
            <router-link to="/ai-tools" class="inline-flex min-h-10 items-center rounded-md bg-primary-600 px-4 py-2 text-sm font-semibold text-white hover:bg-primary-700">打开 AI 工具安装</router-link>
          </div>
          <div class="guide-content" v-html="renderedGuide"></div>
        </article>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'
import DOMPurify from 'dompurify'
import AppLayout from '@/components/layout/AppLayout.vue'
import guideSource from '@/content/hakimi-ai-guide.md?raw'

const anthropicBaseUrl = window.location.origin
const openAiBaseUrl = `${anthropicBaseUrl}/v1`

function slugify(value: string) {
  return value.trim().toLowerCase().replace(/[\s、，。/]+/g, '-').replace(/[^\w\u4e00-\u9fff-]/g, '')
}

const source = guideSource
  .split('{{OPENAI_BASE_URL}}').join(openAiBaseUrl)
  .split('{{ANTHROPIC_BASE_URL}}').join(anthropicBaseUrl)

const headings: Array<{ text: string; id: string }> = []
const headingPattern = /^##\s+(.+)$/gm
let headingMatch: RegExpExecArray | null
while ((headingMatch = headingPattern.exec(source)) !== null) {
  headings.push({ text: headingMatch[1], id: slugify(headingMatch[1]) })
}

const renderer = new marked.Renderer()
renderer.heading = ({ tokens, depth }) => {
  const text = tokens.map(token => 'text' in token ? token.text : token.raw).join('')
  return `<h${depth} id="${slugify(text)}">${text}</h${depth}>`
}
renderer.link = ({ href, title, tokens }) => {
  const text = tokens.map(token => 'text' in token ? token.text : token.raw).join('')
  const titleAttr = title ? ` title="${title}"` : ''
  return `<a href="${href}"${titleAttr} target="_blank" rel="noreferrer">${text}</a>`
}

const renderedGuide = computed(() => DOMPurify.sanitize(marked.parse(source, { renderer }) as string, { ADD_ATTR: ['target', 'rel'] }))
</script>

<style>
.guide-content { color: rgb(55 65 81); font-size: 0.95rem; line-height: 1.8; }
.dark .guide-content { color: rgb(209 213 219); }
.guide-content h1 { margin: 0 0 1rem; color: rgb(17 24 39); font-size: 1.875rem; font-weight: 750; line-height: 1.25; }
.guide-content h2 { scroll-margin-top: 6rem; margin: 2.5rem 0 1rem; border-bottom: 1px solid rgb(229 231 235); padding-bottom: 0.6rem; color: rgb(17 24 39); font-size: 1.35rem; font-weight: 700; }
.guide-content h3 { scroll-margin-top: 6rem; margin: 1.8rem 0 0.7rem; color: rgb(31 41 55); font-size: 1.05rem; font-weight: 700; }
.dark .guide-content h1, .dark .guide-content h2, .dark .guide-content h3 { color: rgb(249 250 251); }
.dark .guide-content h2 { border-color: rgb(55 65 81); }
.guide-content p { margin: 0.8rem 0; }
.guide-content ul, .guide-content ol { margin: 0.8rem 0; padding-left: 1.5rem; }
.guide-content ul { list-style: disc; }
.guide-content ol { list-style: decimal; }
.guide-content li { margin: 0.3rem 0; }
.guide-content a { color: rgb(2 132 199); text-decoration: underline; text-underline-offset: 3px; }
.guide-content code { border-radius: 0.3rem; background: rgb(243 244 246); padding: 0.15rem 0.35rem; color: rgb(190 24 93); font-size: 0.88em; }
.dark .guide-content code { background: rgb(31 41 55); color: rgb(253 164 175); }
.guide-content pre { margin: 1rem 0; overflow-x: auto; border-radius: 0.5rem; background: rgb(3 7 18); padding: 1rem; color: rgb(243 244 246); line-height: 1.65; }
.guide-content pre code { background: transparent; padding: 0; color: inherit; font-size: 0.875rem; }
.guide-content blockquote { margin: 1rem 0; border-left: 4px solid rgb(245 158 11); border-radius: 0 0.4rem 0.4rem 0; background: rgb(255 251 235); padding: 0.8rem 1rem; color: rgb(120 53 15); }
.dark .guide-content blockquote { background: rgb(69 26 3 / 0.35); color: rgb(254 215 170); }
.guide-content table { margin: 1rem 0; width: 100%; border-collapse: collapse; overflow: hidden; border-radius: 0.5rem; font-size: 0.9rem; }
.guide-content th, .guide-content td { border: 1px solid rgb(229 231 235); padding: 0.65rem 0.8rem; text-align: left; vertical-align: top; }
.guide-content th { background: rgb(249 250 251); color: rgb(31 41 55); font-weight: 650; }
.dark .guide-content th, .dark .guide-content td { border-color: rgb(55 65 81); }
.dark .guide-content th { background: rgb(31 41 55); color: rgb(243 244 246); }
@media (max-width: 640px) { .guide-content h1 { font-size: 1.55rem; } .guide-content table { display: block; overflow-x: auto; white-space: nowrap; } }
</style>
