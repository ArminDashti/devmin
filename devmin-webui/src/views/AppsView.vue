<script setup lang="ts">
import { computed, onMounted, onUnmounted } from 'vue'
import { RouterLink } from 'vue-router'
import {
  GRID_CHANNELS,
  channelAvailable,
  endpointFor,
  useStacksStore,
  type GridChannel,
} from '@/lib/stacksStore'
import type { ApplicationDTO } from '@/lib/auth'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'

defineOptions({ name: 'AppsView' })

type GridLine = {
  key: string
  stackDisplay: string
  app: ApplicationDTO
}

const { stacks, initialized, refreshing, error, subscribe, manualRefresh } = useStacksStore()

const gridLines = computed((): GridLine[] => {
  const lines: GridLine[] = []
  for (const stack of stacks.value) {
    stack.applications.forEach((app, idx) => {
      lines.push({
        key: app.id,
        stackDisplay: idx === 0 ? stack.stem : '',
        app,
      })
    })
  }
  return lines
})

function cellEndpoint(app: ApplicationDTO, channel: GridChannel) {
  if (!channelAvailable(app, channel)) {
    return null
  }
  return endpointFor(app, channel)
}

function isRunning(app: ApplicationDTO, channel: GridChannel): boolean {
  const ep = cellEndpoint(app, channel)
  return ep?.status === 'UP'
}

let unsubscribe: (() => void) | null = null

onMounted(() => {
  unsubscribe = subscribe()
})

onUnmounted(() => {
  unsubscribe?.()
})
</script>

<template>
  <div class="w-full space-y-4 px-4 py-6">
    <Card class="w-full">
      <CardHeader class="flex flex-row items-center justify-between gap-3 space-y-0">
        <div class="flex items-center gap-2">
          <CardTitle>Apps</CardTitle>
          <span v-if="refreshing && initialized" class="text-xs text-muted-foreground">Updating…</span>
        </div>
        <Button variant="outline" size="sm" :disabled="refreshing && !initialized" @click="manualRefresh">
          {{ refreshing && !initialized ? 'Loading…' : 'Refresh' }}
        </Button>
      </CardHeader>
      <CardContent class="px-0 pb-0">
        <p v-if="error" class="mb-3 px-6 text-sm text-destructive">{{ error }}</p>
        <div v-if="!initialized && refreshing" class="px-6 py-8 text-sm text-muted-foreground">
          Loading apps…
        </div>
        <div v-else class="w-full overflow-x-auto">
          <Table class="w-full">
            <TableHeader>
              <TableRow>
                <TableHead>Stack</TableHead>
                <TableHead>Application</TableHead>
                <TableHead v-for="col in GRID_CHANNELS" :key="col.id" class="min-w-[7rem] text-center">
                  {{ col.label }}
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-if="gridLines.length === 0">
                <TableCell :colspan="2 + GRID_CHANNELS.length" class="text-muted-foreground">
                  No stacks discovered
                </TableCell>
              </TableRow>
              <TableRow v-for="line in gridLines" :key="line.key">
                <TableCell class="align-top font-medium">
                  <RouterLink
                    v-if="line.stackDisplay"
                    :to="`/stacks/${line.app.stem}`"
                    class="text-primary hover:underline"
                  >
                    {{ line.stackDisplay }}
                  </RouterLink>
                </TableCell>
                <TableCell class="align-top">
                  <RouterLink
                    :to="`/apps/${line.app.id}`"
                    class="font-medium text-primary hover:underline"
                  >
                    {{ line.app.name }}
                  </RouterLink>
                </TableCell>
                <TableCell
                  v-for="col in GRID_CHANNELS"
                  :key="col.id"
                  class="align-top text-center text-sm"
                >
                  <template v-if="isRunning(line.app, col.id)">
                    <a
                      :href="cellEndpoint(line.app, col.id)!.url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="inline-block break-all text-emerald-600 hover:underline dark:text-emerald-400"
                    >
                      {{ cellEndpoint(line.app, col.id)!.url }}
                    </a>
                  </template>
                  <span
                    v-else
                    class="inline-block text-lg leading-none text-red-500"
                    :title="
                      channelAvailable(line.app, col.id)
                        ? 'Not running'
                        : line.app.channels[col.id]?.reason ?? 'Not supported'
                    "
                  >
                    ●
                  </span>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
