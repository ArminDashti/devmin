<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  fetchApplication,
  fetchDockerParams,
  patchDockerParams,
  postAction,
  pollAction,
  type ApplicationDTO,
  type ActionName,
  type Channel,
  type StackDTO,
} from '@/lib/auth'
import { Button } from '@/components/ui/button'
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
const dockerLocal = ref<Record<string, string>>({})
const dockerServer = ref<Record<string, string>>({})
const paramsTarget = ref<'local' | 'server'>('local')

const channels: { id: Channel; label: string; actions: string[] }[] = [
  { id: 'hotReload', label: 'Hot-reload', actions: ['enable', 'disable'] },
  { id: 'local', label: 'Local', actions: ['enable', 'disable'] },
  { id: 'localDocker', label: 'Local Docker', actions: ['install', 'uninstall', 'update', 'reinstall'] },
  { id: 'serverDocker', label: 'Server Docker', actions: ['install', 'uninstall', 'update', 'reinstall'] },
  { id: 'server', label: 'Server', actions: ['install', 'uninstall', 'update', 'reinstall'] },
]

const paramKeys = [
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

const activeParams = computed(() =>
  paramsTarget.value === 'local' ? dockerLocal.value : dockerServer.value,
)

async function load() {
  loading.value = true
  try {
    const res = await fetchApplication(appId.value)
    application.value = res.application
    stack.value = res.stack
    if (stack.value) {
      try {
        const local = await fetchDockerParams(stack.value.stem, 'local')
        dockerLocal.value = local.params
      } catch { /* optional */ }
      try {
        const server = await fetchDockerParams(stack.value.stem, 'server')
        dockerServer.value = server.params
      } catch { /* optional */ }
    }
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load application'
  } finally {
    loading.value = false
  }
}

async function runAction(channel: Channel, action: string) {
  if (!application.value || busy.value) return
  busy.value = true
  error.value = ''
  jobLog.value = ''
  try {
    const job = await postAction({
      appId: application.value.id,
      stem: application.value.stem,
      channel,
      action: action as ActionName,
    })
    const final = await pollAction(job.id, (j) => { jobLog.value = j.output })
    jobLog.value = final.output
    if (final.status === 'failed') error.value = final.error ?? 'Action failed'
    await load()
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Action failed'
  } finally {
    busy.value = false
  }
}

async function saveDockerParams() {
  if (!stack.value || busy.value) return
  busy.value = true
  error.value = ''
  try {
    const res = await patchDockerParams(stack.value.stem, paramsTarget.value, activeParams.value)
    if (paramsTarget.value === 'local') dockerLocal.value = res.params
    else dockerServer.value = res.params
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to save docker params'
  } finally {
    busy.value = false
  }
}

function channelAvailable(channel: Channel): boolean {
  if (!application.value) return false
  const state = application.value.channels[channel]
  return state?.available ?? false
}

watch(appId, () => load(), { immediate: true })
</script>

<template>
  <div class="space-y-4 px-4 py-6">
    <div class="flex items-center gap-2 text-sm text-muted-foreground">
      <RouterLink to="/apps" class="hover:text-foreground">Apps</RouterLink>
      <span>/</span>
      <RouterLink v-if="stack" :to="`/stacks/${stack.stem}`" class="hover:text-foreground">{{ stack.stem }}</RouterLink>
      <span v-if="stack">/</span>
      <span class="text-foreground">{{ appId }}</span>
    </div>

    <Card v-if="application">
      <CardHeader>
        <CardTitle>{{ application.name }}</CardTitle>
        <p class="text-sm text-muted-foreground">Role: {{ application.role }}</p>
      </CardHeader>
      <CardContent class="space-y-6">
        <div class="grid gap-3 md:grid-cols-2">
          <Card v-for="ch in channels" :key="ch.id">
            <CardHeader class="pb-2">
              <CardTitle class="text-base">{{ ch.label }}</CardTitle>
              <p v-if="!channelAvailable(ch.id)" class="text-xs text-muted-foreground">
                {{ application.channels[ch.id]?.reason ?? 'Not available' }}
              </p>
            </CardHeader>
            <CardContent class="flex flex-wrap gap-2">
              <Button
                v-for="act in ch.actions"
                :key="act"
                size="sm"
                variant="outline"
                :disabled="busy || !channelAvailable(ch.id)"
                @click="runAction(ch.id, act)"
              >
                {{ act }}
              </Button>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader class="pb-2">
            <CardTitle class="text-base">Docker params</CardTitle>
          </CardHeader>
          <CardContent class="space-y-3">
            <div class="flex gap-2">
              <Button size="sm" :variant="paramsTarget === 'local' ? 'default' : 'outline'" @click="paramsTarget = 'local'">
                Local
              </Button>
              <Button size="sm" :variant="paramsTarget === 'server' ? 'default' : 'outline'" @click="paramsTarget = 'server'">
                Server
              </Button>
            </div>
            <div class="grid gap-2 sm:grid-cols-2">
              <label v-for="key in paramKeys" :key="key" class="text-sm">
                <span class="text-muted-foreground">{{ key }}</span>
                <input
                  v-model="activeParams[key]"
                  class="mt-1 w-full rounded border border-input bg-background px-2 py-1 text-sm"
                />
              </label>
            </div>
            <Button size="sm" :disabled="busy" @click="saveDockerParams">Save params</Button>
          </CardContent>
        </Card>
      </CardContent>
    </Card>

    <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
    <pre v-if="jobLog" class="max-h-48 overflow-auto rounded border bg-muted p-3 text-xs">{{ jobLog }}</pre>
  </div>
</template>
