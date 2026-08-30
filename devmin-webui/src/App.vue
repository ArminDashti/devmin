<script setup lang="ts">
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { clearSession, getToken } from '@/lib/auth'
import { computed } from 'vue'

const router = useRouter()
const isAuthenticated = computed(() => !!getToken())

function onLogout() {
  clearSession()
  void router.push('/login')
}
</script>

<template>
  <div class="flex h-full w-full flex-col bg-background text-foreground">
    <header class="sticky top-0 z-40 flex shrink-0 items-center justify-between gap-4 border-b border-border px-4 py-3.5">
      <nav class="flex items-center gap-3">
        <RouterLink to="/" class="text-base font-semibold tracking-tight">Devmin</RouterLink>
        <RouterLink to="/apps" class="text-sm text-muted-foreground hover:text-foreground">Apps</RouterLink>
      </nav>
      <div class="flex items-center gap-2">
        <Button v-if="isAuthenticated" variant="ghost" size="sm" @click="onLogout">Log out</Button>
        <RouterLink v-else to="/login">
          <Button variant="outline" size="sm">Log in</Button>
        </RouterLink>
      </div>
    </header>
    <main class="min-h-0 flex-1 overflow-auto">
      <RouterView />
    </main>
  </div>
</template>
