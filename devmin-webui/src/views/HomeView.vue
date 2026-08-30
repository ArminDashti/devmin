<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <div class="mx-auto max-w-3xl px-4 py-14">
    <h1 class="text-2xl font-semibold tracking-tight">Devmin</h1>
    <p class="mt-2 text-muted-foreground">
      Dashboard for local, Docker, and server API–WebUI pairs.
    </p>
    <p class="mt-4">
      <RouterLink to="/apps" class="text-primary hover:underline">Open Apps grid →</RouterLink>
    </p>
  </div>
</template>
