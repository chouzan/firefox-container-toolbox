<script lang="ts">
  import { subscribe, dismiss, type ToastItem } from "./toast.js";

  let toasts = $state<ToastItem[]>([]);

  $effect(() => subscribe((items) => (toasts = items)));
</script>

{#if toasts.length > 0}
  <div class="toast toast-bottom toast-end z-50 max-w-sm">
    {#each toasts as t (t.id)}
      <div
        class="alert shadow-lg text-sm py-2 px-3 min-w-0"
        class:alert-success={t.type === "success"}
        class:alert-error={t.type === "error"}
        class:alert-info={t.type === "info"}
        class:alert-warning={t.type === "warning"}
      >
        <span class="flex-1 break-words">{t.message}</span>
        <button
          class="btn btn-ghost btn-xs flex-shrink-0"
          onclick={() => dismiss(t.id)}
        >
          ✕
        </button>
      </div>
    {/each}
  </div>
{/if}
