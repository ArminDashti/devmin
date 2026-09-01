<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  fetchApplication,
  fetchDockerParams,
  fetchServerParams,
  patchDockerParams,
  patchServerParams,
  postAction,
  pollAction,
  type ApplicationDTO,
  type ActionName,
  type Channel,
  type StackDTO,
} from '@/lib/auth'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { RouterLink } from 'vue-router'

const route = useRoute()
const appId = computed(() => String(route.params.appId))
const application = ref<ApplicationDTO | null>(null)
const stack = ref<StackDTO | null>(null)
const loading = ref(false)
const error = ref('')
const jobLog = ref('')
const busy = ref(false)
const activeJob = ref<{ channel: Channel; action: string } | null>(null)
const dockerLocal = ref<Record<string, string>>({})
const dockerServer = ref<Record<string, string>>({})
const serverParams = ref<Record<string, string>>({})
const paramsSaved = ref<Record<string, boolean>>({})

type DeployAction = { id: ActionName; label: string; destructive?: boolean }

const deployActions: DeployAction[] = [
  { id: 'install', label: 'Install' },
  { id: 'update', label: 'Update' },
  { id: 'uninstall', label: 'Remove', destructive: true },
  { id: 'reinstall', label: 'Reinstall', destructive: true },
]

const dockerParamKeys = [
  'stack_name',
  'image_tag',
  'compose_file',
  'dockerfile',
  'docker_network',
  'internal_port',
  'publish_port',
  'delete_volume',
  'delete_image',
]

const serverDockerExtraKeys = ['build_image_on', 'ssh', 'volume_dir']

const serverParamKeys = ['stack_name', 'ssh', 'deploy_root', 'public_url']

const paramLabels: Record<string, string> = {
  stack_name: 'Stack name',
  image_tag: 'Image tag',
  compose_file: 'Compose file',
  dockerfile: 'Dockerfile',
  docker_network: 'Docker network',
  internal_port: 'Internal port',
  publish_port: 'Publish port',
  delete_volume: 'Delete volume',
  delete_image: 'Delete image',
  build_image_on: 'Build image on',
  ssh: 'SSH',
  volume_dir: 'Volume dir',
  deploy_root: 'Deploy root',
  public_url: 'Public URL',
}

function mergeParams(raw: Record<string, string>, keys: string[]): Record<string, string> {
  const out: Record<string, string> = {}
  for (const key of keys) {
    out[key] = raw[key] ?? ''
  }
  for (const [key, value] of Object.entries(raw)) {
    if (!(key in out)) out[key] = value
  }
  return out
}

const displayPort = computed(() => {
  const publish = dockerLocal.value.publish_port?.trim()
  if (publish) return publish
  return application.value ? String(application.value.internalPort) : '—'
})

async function load() {
  loading.value = true
  try {
    const res = await fetchApplication(appId.value)
    application.value = res.application
    stack.value = res.stack
    if (application.value) {
      try {
        const local = await fetchDockerParams(application.value.id, 'local')
        dockerLocal.value = mergeParams(local.params, [...dockerParamKeys, 'build_image_on', 'ssh', 'volume_dir'])
      } catch { /* optional */ }
      try {
        const server = await fetchDockerParams(application.value.id, 'server')
        dockerServer.value = mergeParams(server.params, [...dockerParamKeys, ...serverDockerExtraKeys])
      } catch { /* optional */ }
      try {
        const server = await fetchServerParams(application.value.id)
        serverParams.value = mergeParams(server.params, serverParamKeys)
      } catch { /* optional */ }
    }
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load application'
  } finally {
    loading.value = false
  }
}

async function runAction(channel: Channel, action: ActionName) {
  if (!application.value || busy.value) return
  busy.value = true
  activeJob.value = { channel, action }
  error.value = ''
  jobLog.value = ''
  try {
    const job = await postAction({
      appId: application.value.id,
      stem: application.value.stem,
      channel,
      action,
    })
    const final = await pollAction(job.id, (j) => { jobLog.value = j.output })
    jobLog.value = final.output
    if (final.status === 'failed') error.value = final.error ?? 'Action failed'
    await load()
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Action failed'
  } finally {
    busy.value = false
    activeJob.value = null
  }
}

async function saveDockerParams(target: 'local' | 'server') {
  if (!application.value || busy.value) return
  busy.value = true
  paramsSaved.value[`docker-${target}`] = false
  error.value = ''
  try {
    const params = target === 'local' ? dockerLocal.value : dockerServer.value
    const res = await patchDockerParams(application.value.id, target, params)
    const merged = mergeParams(res.params, [...dockerParamKeys, ...serverDockerExtraKeys])
    if (target === 'local') dockerLocal.value = merged
    else dockerServer.value = merged
    paramsSaved.value[`docker-${target}`] = true
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to save docker params'
  } finally {
    busy.value = false
  }
}

async function saveServerParams() {
  if (!application.value || busy.value) return
  busy.value = true
  paramsSaved.value.server = false
  error.value = ''
  try {
    const res = await patchServerParams(application.value.id, serverParams.value)
    serverParams.value = mergeParams(res.params, serverParamKeys)
    paramsSaved.value.server = true
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to save server params'
  } finally {
    busy.value = false
  }
}

function channelAvailable(channel: Channel): boolean {
  if (!application.value) return false
  return application.value.channels[channel]?.available ?? false
}

function isJobRunning(channel: Channel, action: string): boolean {
  return activeJob.value?.channel === channel && activeJob.value?.action === action
}

function channelReason(channel: Channel): string {
  return application.value?.channels[channel]?.reason ?? 'Not available'
}

watch(appId, () => load(), { immediate: true })
</script>

<template>
  <div class="w-full space-y-4 px-4 py-6">
    <nav class="flex flex-wrap items-center gap-1.5 text-sm text-muted-foreground">
      <RouterLink to="/apps" class="hover:text-foreground">Apps</RouterLink>
      <span aria-hidden="true">/</span>
      <RouterLink v-if="stack" :to="`/stacks/${stack.stem}`" class="hover:text-foreground">
        {{ stack.stem }}
      </RouterLink>
      <span v-if="stack" aria-hidden="true">/</span>
      <span class="font-medium text-foreground">{{ appId }}</span>
    </nav>

    <div v-if="loading && !application" class="py-16 text-center text-sm text-muted-foreground">
      Loading application…
    </div>

    <template v-else-if="application">
      <div class="flex flex-wrap items-start justify-between gap-4">
        <div class="space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="text-2xl font-semibold tracking-tight">{{ application.name }}</h1>
            <Badge variant="secondary">{{ application.role }}</Badge>
          </div>
          <p v-if="stack" class="text-sm text-muted-foreground">
            Stack
            <RouterLink :to="`/stacks/${stack.stem}`" class="text-primary hover:underline">
              {{ stack.stem }}
            </RouterLink>
          </p>
        </div>
        <Button variant="outline" size="sm" :disabled="loading || busy" @click="load">
          {{ loading ? 'Refreshing…' : 'Refresh' }}
        </Button>
      </div>

      <!-- Local -->
      <Card :class="cn(!channelAvailable('local') && 'opacity-60')">
        <CardHeader class="pb-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <CardTitle class="text-base">Local</CardTitle>
            <Badge v-if="!channelAvailable('local')" variant="outline" class="text-[10px]">
              {{ channelReason('local') }}
            </Badge>
          </div>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="flex flex-wrap gap-2">
            <Button
              v-for="act in deployActions"
              :key="act.id"
              size="sm"
              :variant="act.destructive ? 'outline' : 'default'"
              :class="act.destructive ? 'border-destructive/40 text-destructive hover:bg-destructive/10' : ''"
              :disabled="busy || !channelAvailable('local')"
              @click="runAction('local', act.id)"
            >
              <span
                v-if="isJobRunning('local', act.id)"
                class="mr-1 inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent"
              />
              {{ isJobRunning('local', act.id) ? 'Running…' : act.label }}
            </Button>
          </div>
          <div class="rounded-md border bg-muted/30 px-3 py-2">
            <p class="text-xs font-medium text-muted-foreground">Port</p>
            <p class="text-sm font-mono">{{ displayPort }}</p>
          </div>
        </CardContent>
      </Card>

      <!-- Local Docker -->
      <Card :class="cn(!channelAvailable('localDocker') && 'opacity-60')">
        <CardHeader class="pb-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <CardTitle class="text-base">Local Docker</CardTitle>
            <Badge v-if="!channelAvailable('localDocker')" variant="outline" class="text-[10px]">
              {{ channelReason('localDocker') }}
            </Badge>
          </div>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="flex flex-wrap gap-2">
            <Button
              v-for="act in deployActions"
              :key="act.id"
              size="sm"
              :variant="act.destructive ? 'outline' : 'default'"
              :class="act.destructive ? 'border-destructive/40 text-destructive hover:bg-destructive/10' : ''"
              :disabled="busy || !channelAvailable('localDocker')"
              @click="runAction('localDocker', act.id)"
            >
              <span
                v-if="isJobRunning('localDocker', act.id)"
                class="mr-1 inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent"
              />
              {{ isJobRunning('localDocker', act.id) ? 'Running…' : act.label }}
            </Button>
          </div>
          <div class="space-y-3 border-t pt-4">
            <p class="text-xs font-medium text-muted-foreground">Docker params</p>
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              <label v-for="key in dockerParamKeys" :key="key" class="block text-sm">
                <span class="mb-1 block text-xs font-medium text-muted-foreground">
                  {{ paramLabels[key] ?? key }}
                </span>
                <input
                  v-model="dockerLocal[key]"
                  :name="`local-docker-${key}`"
                  class="w-full rounded-md border border-input bg-background px-3 py-1.5 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
              </label>
            </div>
            <div class="flex items-center gap-3">
              <Button size="sm" :disabled="busy" @click="saveDockerParams('local')">
                Save params
              </Button>
              <span v-if="paramsSaved['docker-local']" class="text-xs text-emerald-600 dark:text-emerald-400">
                Saved
              </span>
            </div>
          </div>
        </CardContent>
      </Card>

      <!-- Server Docker -->
      <Card :class="cn(!channelAvailable('serverDocker') && 'opacity-60')">
        <CardHeader class="pb-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <CardTitle class="text-base">Server Docker</CardTitle>
            <Badge v-if="!channelAvailable('serverDocker')" variant="outline" class="text-[10px]">
              {{ channelReason('serverDocker') }}
            </Badge>
          </div>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="flex flex-wrap gap-2">
            <Button
              v-for="act in deployActions"
              :key="act.id"
              size="sm"
              :variant="act.destructive ? 'outline' : 'default'"
              :class="act.destructive ? 'border-destructive/40 text-destructive hover:bg-destructive/10' : ''"
              :disabled="busy || !channelAvailable('serverDocker')"
              @click="runAction('serverDocker', act.id)"
            >
              <span
                v-if="isJobRunning('serverDocker', act.id)"
                class="mr-1 inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent"
              />
              {{ isJobRunning('serverDocker', act.id) ? 'Running…' : act.label }}
            </Button>
          </div>
          <div class="space-y-3 border-t pt-4">
            <p class="text-xs font-medium text-muted-foreground">Docker params</p>
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              <label
                v-for="key in [...dockerParamKeys, ...serverDockerExtraKeys]"
                :key="key"
                class="block text-sm"
              >
                <span class="mb-1 block text-xs font-medium text-muted-foreground">
                  {{ paramLabels[key] ?? key }}
                </span>
                <input
                  v-model="dockerServer[key]"
                  :name="`server-docker-${key}`"
                  class="w-full rounded-md border border-input bg-background px-3 py-1.5 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
              </label>
            </div>
            <div class="flex items-center gap-3">
              <Button size="sm" :disabled="busy" @click="saveDockerParams('server')">
                Save params
              </Button>
              <span v-if="paramsSaved['docker-server']" class="text-xs text-emerald-600 dark:text-emerald-400">
                Saved
              </span>
            </div>
          </div>
        </CardContent>
      </Card>

      <!-- Server -->
      <Card :class="cn(!channelAvailable('server') && 'opacity-60')">
        <CardHeader class="pb-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <CardTitle class="text-base">Server</CardTitle>
            <Badge v-if="!channelAvailable('server')" variant="outline" class="text-[10px]">
              {{ channelReason('server') }}
            </Badge>
          </div>
        </CardHeader>
        <CardContent class="space-y-4">
          <div class="flex flex-wrap gap-2">
            <Button
              v-for="act in deployActions"
              :key="act.id"
              size="sm"
              :variant="act.destructive ? 'outline' : 'default'"
              :class="act.destructive ? 'border-destructive/40 text-destructive hover:bg-destructive/10' : ''"
              :disabled="busy || !channelAvailable('server')"
              @click="runAction('server', act.id)"
            >
              <span
                v-if="isJobRunning('server', act.id)"
                class="mr-1 inline-block h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent"
              />
              {{ isJobRunning('server', act.id) ? 'Running…' : act.label }}
            </Button>
          </div>
          <div class="space-y-3 border-t pt-4">
            <p class="text-xs font-medium text-muted-foreground">Params</p>
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              <label v-for="key in serverParamKeys" :key="key" class="block text-sm">
                <span class="mb-1 block text-xs font-medium text-muted-foreground">
                  {{ paramLabels[key] ?? key }}
                </span>
                <input
                  v-model="serverParams[key]"
                  :name="`server-${key}`"
                  class="w-full rounded-md border border-input bg-background px-3 py-1.5 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
              </label>
            </div>
            <div class="flex items-center gap-3">
              <Button size="sm" :disabled="busy" @click="saveServerParams">
                Save params
              </Button>
              <span v-if="paramsSaved.server" class="text-xs text-emerald-600 dark:text-emerald-400">
                Saved
              </span>
            </div>
          </div>
        </CardContent>
      </Card>
    </template>

    <div
      v-if="error"
      class="rounded-md border border-destructive/30 bg-destructive/10 px-4 py-3 text-sm text-destructive"
      role="alert"
    >
      {{ error }}
    </div>

    <Card v-if="jobLog">
      <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-base">Job output</CardTitle>
        <Button variant="ghost" size="sm" @click="jobLog = ''">Clear</Button>
      </CardHeader>
      <CardContent class="p-0">
        <pre class="max-h-64 overflow-auto rounded-b-lg bg-zinc-950 px-4 py-3 font-mono text-xs leading-relaxed text-zinc-100">{{ jobLog }}</pre>
      </CardContent>
    </Card>
  </div>
</template>
