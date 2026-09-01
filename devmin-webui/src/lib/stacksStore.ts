import { ref, shallowRef } from 'vue'
import { fetchStacks, type ApplicationDTO, type EndpointLine, type StackDTO } from '@/lib/api'

export type GridChannel = 'local' | 'localDocker' | 'serverDocker' | 'server'

export const GRID_CHANNELS: { id: GridChannel; label: string }[] = [
  { id: 'local', label: 'Local' },
  { id: 'localDocker', label: 'Local Docker' },
  { id: 'serverDocker', label: 'Server Docker' },
  { id: 'server', label: 'Server' },
]

const stacks = shallowRef<StackDTO[]>([])
const initialized = ref(false)
const refreshing = ref(false)
const error = ref('')

let pollTimer: ReturnType<typeof setInterval> | null = null
let subscriberCount = 0

export function endpointFor(app: ApplicationDTO, channel: GridChannel): EndpointLine | undefined {
  return app.endpoints.find((ep) => ep.channel === channel)
}

export function channelAvailable(app: ApplicationDTO, channel: GridChannel): boolean {
  return app.channels[channel]?.available ?? false
}

async function refresh(silent: boolean) {
  if (!silent || !initialized.value) {
    refreshing.value = true
  }
  try {
    const res = await fetchStacks()
    stacks.value = res.stacks ?? []
    initialized.value = true
    error.value = ''
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load stacks'
  } finally {
    refreshing.value = false
  }
}

function startPolling() {
  if (pollTimer !== null) return
  pollTimer = setInterval(() => {
    void refresh(true)
  }, 8000)
}

function stopPolling() {
  if (pollTimer !== null) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

export function useStacksStore() {
  function subscribe() {
    subscriberCount += 1
    startPolling()
    if (!initialized.value) {
      void refresh(false)
    } else {
      void refresh(true)
    }
    return () => {
      subscriberCount -= 1
      if (subscriberCount <= 0) {
        stopPolling()
      }
    }
  }

  function manualRefresh() {
    return refresh(false)
  }

  return {
    stacks,
    initialized,
    refreshing,
    error,
    subscribe,
    manualRefresh,
  }
}
