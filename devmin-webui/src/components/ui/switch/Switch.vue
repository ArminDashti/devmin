<script setup lang="ts">
import { computed } from 'vue'
import { cn } from '@/lib/utils'

const props = withDefaults(
  defineProps<{
    checked?: boolean
    disabled?: boolean
    class?: string
  }>(),
  { checked: false, disabled: false, class: '' },
)

const emit = defineEmits<{ change: [checked: boolean] }>()

const classes = computed(() =>
  cn(
    'peer inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50',
    props.checked ? 'bg-primary' : 'bg-input',
    props.class,
  ),
)
</script>

<template>
  <button
    type="button"
    role="switch"
    :aria-checked="checked"
    :class="classes"
    :disabled="disabled"
    @click="emit('change', !checked)"
  >
    <span
      :class="cn(
        'pointer-events-none block h-5 w-5 rounded-full bg-background shadow-lg ring-0 transition-transform',
        checked ? 'translate-x-5' : 'translate-x-0',
      )"
    />
  </button>
</template>
