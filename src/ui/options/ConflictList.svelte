<script lang="ts">
  import { Action, sendMessage } from "../shared/messaging.js";
  import { toast } from "../shared/toast.js";

  interface Conflict {
    id: string;
    type: string;
    description: string;
    localValue: { name: string; color: string; icon: string } | null;
    remoteValue: unknown;
  }

  let conflicts = $state<Conflict[]>([]);
  let resolving = $state<string | null>(null);

  export const load = async () => {
    try {
      conflicts = await sendMessage<Conflict[]>(Action.getConflicts);
    } catch {
      conflicts = [];
    }
  };

  async function resolve(id: string, action: "keep" | "remove") {
    resolving = id;
    try {
      conflicts = await sendMessage<Conflict[]>(Action.resolveConflict, {
        id,
        action,
      });
    } catch (err) {
      toast.error(
        err instanceof Error ? err.message : "Failed to resolve conflict",
      );
    } finally {
      resolving = null;
    }
  }

  load();
</script>

{#if conflicts.length > 0}
  <div class="card bg-base-200">
    <div class="card-body p-4 gap-3">
      <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">
        Pending Conflicts
      </h2>
      <p class="opacity-50 text-sm">
        These containers exist locally but not in the imported config.
      </p>
      <ul class="flex flex-col gap-0.5">
        {#each conflicts as c (c.id)}
          <li
            class="flex items-center gap-2.5 px-2 py-1.5 rounded hover:bg-base-300"
          >
            {#if c.localValue}
              <div
                class="usercontext-icon"
                data-identity-icon={c.localValue.icon ?? "circle"}
                data-identity-color={c.localValue.color ?? "toolbar"}
              ></div>
              <span class="flex-1 text-sm">{c.localValue.name}</span>
            {:else}
              <span class="flex-1 text-sm opacity-50">{c.description}</span>
            {/if}
            <span class="flex gap-1">
              <button
                class="btn btn-soft btn-xs"
                disabled={resolving === c.id}
                onclick={() => resolve(c.id, "keep")}
              >
                Keep
              </button>
              <button
                class="btn btn-error btn-outline btn-xs"
                disabled={resolving === c.id}
                onclick={() => resolve(c.id, "remove")}
              >
                Remove
              </button>
            </span>
          </li>
        {/each}
      </ul>
    </div>
  </div>
{/if}
