<script setup lang="ts">
import { cn } from '@/lib/utils'

defineProps<{ class?: string; colspan?: number; rowspan?: number }>()
</script>

<template>
  <td :class="cn('p-4 align-middle', $props.class)" :colspan="colspan" :rowspan="rowspan">
    <slot />
  </td>
</template>
