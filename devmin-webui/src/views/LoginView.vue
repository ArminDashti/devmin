<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { login, setSession } from '@/lib/auth'

const router = useRouter()
const route = useRoute()

const username = ref('')
const password = ref('')
const errorMessage = ref<string | null>(null)
const submitting = ref(false)

async function onSubmit() {
  errorMessage.value = null
  submitting.value = true
  try {
    const result = await login({
      username: username.value.trim(),
      password: password.value,
    })
    setSession(result.token, result.username)
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/apps'
    await router.push(redirect)
  } catch (err) {
    errorMessage.value = err instanceof Error ? err.message : 'Login failed'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="mx-auto flex min-h-full max-w-md items-center px-4 py-14">
    <Card class="w-full">
      <CardHeader>
        <CardTitle class="tracking-tight">Log in</CardTitle>
      </CardHeader>
      <CardContent>
        <form class="space-y-3" @submit.prevent="onSubmit">
          <label class="block space-y-1 text-sm">
            <span>Username</span>
            <input
              v-model="username"
              type="text"
              required
              autocomplete="username"
              class="w-full rounded-md border border-input bg-background px-3 py-2"
            />
          </label>
          <label class="block space-y-1 text-sm">
            <span>Password</span>
            <input
              v-model="password"
              type="password"
              required
              autocomplete="current-password"
              class="w-full rounded-md border border-input bg-background px-3 py-2"
            />
          </label>
          <p v-if="errorMessage" class="text-sm text-destructive">{{ errorMessage }}</p>
          <Button class="w-full" type="submit" :disabled="submitting">
            {{ submitting ? 'Signing in…' : 'Log in' }}
          </Button>
        </form>
      </CardContent>
    </Card>
  </div>
</template>
