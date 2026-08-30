<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { fetchSettings, putSettings, type PlatformSettings } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

const settings = ref<PlatformSettings | null>(null)
const loading = ref(false)
const error = ref('')
const saved = ref(false)

async function load() {
  loading.value = true
  try {
    settings.value = await fetchSettings()
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load settings'
  } finally {
    loading.value = false
  }
}

async function save() {
  if (!settings.value) return
  loading.value = true
  saved.value = false
  try {
    settings.value = await putSettings(settings.value)
    saved.value = true
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to save settings'
  } finally {
    loading.value = false
  }
}

onMounted(() => load())
</script>

<template>
  <div class="space-y-4 px-4 py-6">
    <Card v-if="settings">
      <CardHeader class="flex flex-row items-center justify-between">
        <CardTitle>Settings</CardTitle>
        <Button size="sm" :disabled="loading" @click="save">Save</Button>
      </CardHeader>
      <CardContent class="space-y-6">
        <section>
          <h3 class="mb-2 text-sm font-medium">Local Docker</h3>
          <div class="grid gap-2 sm:grid-cols-2">
            <label class="text-sm">
              Network
              <input v-model="settings.localDocker.network" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              Publish host
              <input v-model="settings.localDocker.publishHost" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              GitHub root
              <input v-model="settings.localDocker.githubRoot" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              Delete volume default
              <input v-model="settings.localDocker.deleteVolume" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              Delete image default
              <input v-model="settings.localDocker.deleteImage" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
          </div>
        </section>

        <section>
          <h3 class="mb-2 text-sm font-medium">Server Docker</h3>
          <div class="grid gap-2 sm:grid-cols-2">
            <label class="text-sm">
              SSH target
              <input v-model="settings.serverDocker.sshTarget" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              Volume base
              <input v-model="settings.serverDocker.volumeBase" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              Timeout (sec)
              <input v-model.number="settings.serverDocker.timeoutSec" type="number" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
          </div>
        </section>

        <section>
          <h3 class="mb-2 text-sm font-medium">Server</h3>
          <div class="grid gap-2 sm:grid-cols-2">
            <label class="text-sm">
              SSH target
              <input v-model="settings.server.sshTarget" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              Deploy root
              <input v-model="settings.server.deployRoot" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
            <label class="text-sm">
              SSH env key
              <input v-model="settings.server.sshEnvKey" class="mt-1 w-full rounded border px-2 py-1 text-sm" />
            </label>
          </div>
        </section>

        <p v-if="saved" class="text-sm text-emerald-600">Settings saved.</p>
      </CardContent>
    </Card>
    <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
  </div>
</template>
