<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import {
  fetchStack,
  postAction,
  pollAction,
  type ActionName,
  type Channel,
  type StackDTO,
} from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { RouterLink } from 'vue-router'

const route = useRoute()
const stem = computed(() => String(route.params.stem))
const stack = ref<StackDTO | null>(null)
const loading = ref(false)
const error = ref('')
const jobLog = ref('')
const busy = ref(false)

const channels: { id: Channel; label: string; actions: string[] }[] = [
  { id: 'hotReload', label: 'Hot-reload', actions: ['enable', 'disable'] },
  { id: 'localDocker', label: 'Local Docker', actions: ['install', 'uninstall', 'update', 'reinstall'] },
  { id: 'serverDocker', label: 'Server Docker', actions: ['install', 'uninstall', 'update', 'reinstall'] },
  { id: 'server', label: 'Server', actions: ['install', 'uninstall', 'update', 'reinstall'] },
]

async function load() {
  loading.value = true
  try {
    stack.value = await fetchStack(stem.value)
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load stack'
  } finally {
    loading.value = false
  }
}

async function runAction(channel: Channel, action: string) {
  if (!stack.value || busy.value) return
  busy.value = true
  error.value = ''
  jobLog.value = ''
  try {
    const job = await postAction({ stem: stack.value.stem, channel, action: action as ActionName })
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

watch(stem, () => load(), { immediate: true })
</script>

<template>
  <div class="space-y-4 px-4 py-6">
    <div class="flex items-center gap-2 text-sm text-muted-foreground">
      <RouterLink to="/apps" class="hover:text-foreground">Apps</RouterLink>
      <span>/</span>
      <span class="text-foreground">{{ stem }}</span>
    </div>

    <Card v-if="stack">
      <CardHeader>
        <CardTitle>Stack {{ stack.stem }}</CardTitle>
        <p class="text-sm text-muted-foreground">Type: {{ stack.type }} · {{ stack.rootDir }}</p>
      </CardHeader>
      <CardContent class="space-y-4">
        <div>
          <h3 class="mb-2 text-sm font-medium">Applications</h3>
          <ul class="space-y-1 text-sm">
            <li v-for="app in stack.applications" :key="app.id">
              <RouterLink :to="`/apps/${app.id}`" class="text-primary hover:underline">{{ app.name }}</RouterLink>
              <span class="text-muted-foreground"> ({{ app.role }})</span>
            </li>
          </ul>
        </div>

        <div class="grid gap-3 md:grid-cols-2">
          <Card v-for="ch in channels" :key="ch.id">
            <CardHeader class="pb-2">
              <CardTitle class="text-base">{{ ch.label }}</CardTitle>
            </CardHeader>
            <CardContent class="flex flex-wrap gap-2">
              <Button
                v-for="act in ch.actions"
                :key="act"
                size="sm"
                variant="outline"
                :disabled="busy"
                @click="runAction(ch.id, act)"
              >
                {{ act }}
              </Button>
            </CardContent>
          </Card>
        </div>

        <RouterLink :to="`/apps/${stack.applications[0]?.id}`" class="text-sm text-primary hover:underline">
          Edit docker params on application page
        </RouterLink>
      </CardContent>
    </Card>

    <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
    <pre v-if="jobLog" class="max-h-48 overflow-auto rounded border bg-muted p-3 text-xs">{{ jobLog }}</pre>
  </div>
</template>
