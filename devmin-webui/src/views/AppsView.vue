<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { fetchApps, patchApp, type AppRow, type RunMode } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Switch } from '@/components/ui/switch'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'

const LOOPBACK_HOST = '127.0.0.1'

type GridLine = {
  key: string
  stem: string
  source: AppRow
  stackDisplay: string
  appName: string
  internalUrl: string
  isPairLead: boolean
  pairRowSpan: number
  role: 'api' | 'webui'
}

type ModeEntry = {
  label: string
  runMode: RunMode
  enabled: (row: AppRow) => boolean
  url: (row: AppRow, role: 'api' | 'webui') => string
  status: (row: AppRow) => 'UP' | 'Down'
  disabled: (row: AppRow) => boolean
  title: (row: AppRow) => string
}

const MODE_COLUMNS: ModeEntry[] = [
  {
    label: 'Local',
    runMode: 'local',
    enabled: (row) => row.localEnabled,
    url: (row, role) => (role === 'api' ? row.localApiUrl : row.localWebuiUrl),
    status: (row) => row.localStatus,
    disabled: () => false,
    title: () => '',
  },
  {
    label: 'Docker',
    runMode: 'localDocker',
    enabled: (row) => row.dockerEnabled,
    url: (row, role) => (role === 'api' ? row.dockerApiUrl : row.dockerWebuiUrl),
    status: (row) => row.dockerStatus,
    disabled: (row) => !!row.skipReason,
    title: (row) => row.skipReason ?? '',
  },
  {
    label: 'Public',
    runMode: 'server',
    enabled: (row) => row.publicEnabled,
    url: (row, role) => (role === 'api' ? row.publicApiUrl : row.publicWebuiUrl),
    status: (row) => row.publicStatus,
    disabled: (row) => !row.hasServerDeploy,
    title: () => 'Server deploy scripts missing or invalid',
  },
]

const apps = ref<AppRow[]>([])
const loading = ref(false)
const error = ref('')
const toggling = ref<Record<string, boolean>>({})

const gridLines = computed((): GridLine[] => {
  const lines: GridLine[] = []
  for (const row of apps.value) {
    const apiApp = row.apiApp || `${row.stem}-api`
    const webuiApp = row.webuiApp || ''
    const pairRowSpan = webuiApp ? 2 : 1
    lines.push({
      key: `${row.stem}-api`,
      stem: row.stem,
      source: row,
      stackDisplay: row.stem,
      appName: apiApp,
      internalUrl: internalHref(row.apiInternalPort),
      isPairLead: true,
      pairRowSpan,
      role: 'api',
    })
    if (webuiApp) {
      lines.push({
        key: `${row.stem}-webui`,
        stem: row.stem,
        source: row,
        stackDisplay: '',
        appName: webuiApp,
        internalUrl: internalHref(row.webuiInternalPort),
        isPairLead: false,
        pairRowSpan,
        role: 'webui',
      })
    }
  }
  return lines
})

function internalHref(port: number): string {
  if (!port || port <= 0) return ''
  return `http://${LOOPBACK_HOST}:${port}/`
}

function internalLabel(port: number): string {
  if (!port || port <= 0) return '—'
  return `${LOOPBACK_HOST}:${port}`
}

async function load() {
  loading.value = true
  try {
    const res = await fetchApps()
    apps.value = res.apps ?? []
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load apps'
  } finally {
    loading.value = false
  }
}

async function onModeToggle(row: AppRow, mode: ModeEntry, enabled: boolean) {
  if (busy(row) || mode.disabled(row)) return
  toggling.value = { ...toggling.value, [row.stem]: true }
  error.value = ''
  try {
    const updated = await patchApp(row.stem, { runMode: mode.runMode, enabled })
    apps.value = apps.value.map((a) => (a.stem === row.stem ? { ...a, ...updated } : a))
    setTimeout(load, 2000)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Toggle failed'
    await load()
  } finally {
    const next = { ...toggling.value }
    delete next[row.stem]
    toggling.value = next
  }
}

function busy(row: AppRow): boolean {
  return row.actionInProgress || !!toggling.value[row.stem]
}

function statusLabel(url: string): string {
  if (!url) return ''
  return url
}

function statusClass(status: 'UP' | 'Down'): string {
  return status === 'UP' ? 'text-emerald-600 dark:text-emerald-400' : 'text-muted-foreground'
}

let timer: ReturnType<typeof setInterval> | null = null

onMounted(() => {
  void load()
  timer = setInterval(load, 8000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<template>
  <div class="w-full space-y-4 px-4 py-6">
    <Card class="w-full">
      <CardHeader class="flex flex-row items-center justify-between gap-3 space-y-0">
        <CardTitle>Apps</CardTitle>
        <Button variant="outline" size="sm" :disabled="loading" @click="load">
          {{ loading ? 'Refreshing…' : 'Refresh' }}
        </Button>
      </CardHeader>
      <CardContent class="px-0 pb-0">
        <p v-if="error" class="mb-3 px-6 text-sm text-destructive">{{ error }}</p>
        <div class="w-full overflow-x-auto">
          <Table class="w-full">
            <TableHeader>
              <TableRow>
                <TableHead>Stack</TableHead>
                <TableHead>App</TableHead>
                <TableHead>URL</TableHead>
                <TableHead v-for="mode in MODE_COLUMNS" :key="mode.runMode">{{ mode.label }}</TableHead>
                <TableHead>Status</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="gridLines.length === 0">
                <TableCell :colspan="7" class="text-muted-foreground">No app pairs discovered</TableCell>
              </TableRow>
              <TableRow v-for="line in gridLines" :key="line.key">
                <TableCell class="font-medium" :title="line.source.stem">
                  {{ line.stackDisplay }}
                </TableCell>
                <TableCell>{{ line.appName }}</TableCell>
                <TableCell class="text-sm">
                  <a
                    v-if="line.internalUrl"
                    :href="line.internalUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-primary hover:underline"
                  >
                    {{ internalLabel(line.role === 'api' ? line.source.apiInternalPort : line.source.webuiInternalPort) }}
                  </a>
                  <span v-else class="text-muted-foreground">—</span>
                </TableCell>
                <template v-if="line.isPairLead">
                  <TableCell
                    v-for="mode in MODE_COLUMNS"
                    :key="`${line.stem}-${mode.runMode}`"
                    :rowspan="line.pairRowSpan"
                    class="align-middle"
                  >
                    <div class="flex items-center gap-2">
                      <Switch
                        :checked="mode.enabled(line.source)"
                        :disabled="busy(line.source) || mode.disabled(line.source)"
                        :title="mode.title(line.source)"
                        @change="(v: boolean) => onModeToggle(line.source, mode, v)"
                      />
                      <span
                        v-if="mode.disabled(line.source)"
                        class="text-xs text-muted-foreground"
                        :title="mode.title(line.source)"
                      >
                        n/a
                      </span>
                      <span v-else-if="busy(line.source)" class="text-xs text-muted-foreground">…</span>
                    </div>
                  </TableCell>
                </template>
                <TableCell class="text-sm align-top">
                  <div class="space-y-1">
                    <div v-for="mode in MODE_COLUMNS" :key="`${line.key}-status-${mode.runMode}`" class="flex flex-wrap items-baseline gap-x-2">
                      <span class="w-12 shrink-0 text-xs font-medium text-muted-foreground">{{ mode.label }}</span>
                      <a
                        v-if="statusLabel(mode.url(line.source, line.role))"
                        :href="mode.url(line.source, line.role)"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="break-all hover:underline"
                        :class="statusClass(mode.status(line.source))"
                      >
                        {{ statusLabel(mode.url(line.source, line.role)) }}
                      </a>
                      <span v-else class="text-muted-foreground">—</span>
                      <span class="text-xs" :class="statusClass(mode.status(line.source))">
                        {{ mode.status(line.source) }}
                      </span>
                    </div>
                  </div>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
