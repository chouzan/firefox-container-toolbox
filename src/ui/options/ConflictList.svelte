<script lang="ts">
  import { Action, sendMessage } from "../shared/messaging.js";

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
      console.error("Failed to resolve conflict:", err);
    } finally {
      resolving = null;
    }
  }

  load();
</script>

{#if conflicts.length > 0}
  <section class="card">
    <h2>Pending Conflicts</h2>
    <p class="muted">
      These containers exist locally but not in the imported config.
    </p>
    <ul class="conflict-list">
      {#each conflicts as c (c.id)}
        <li class="conflict-row">
          {#if c.localValue}
            <div
              class="usercontext-icon"
              data-identity-icon={c.localValue.icon ?? "circle"}
              data-identity-color={c.localValue.color ?? "toolbar"}
            ></div>
            <span class="conflict-name">{c.localValue.name}</span>
          {:else}
            <span class="conflict-name muted">{c.description}</span>
          {/if}
          <span class="conflict-actions">
            <button
              class="btn btn-secondary btn-sm"
              disabled={resolving === c.id}
              onclick={() => resolve(c.id, "keep")}
            >
              Keep
            </button>
            <button
              class="btn btn-danger btn-sm"
              disabled={resolving === c.id}
              onclick={() => resolve(c.id, "remove")}
            >
              Remove
            </button>
          </span>
        </li>
      {/each}
    </ul>
  </section>
{/if}

<style>
  .conflict-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .conflict-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 8px;
    border-radius: var(--radius);
  }
  .conflict-row:hover {
    background: var(--bg-hover);
  }

  .conflict-name {
    flex: 1;
  }

  .conflict-actions {
    display: flex;
    gap: 4px;
  }
</style>
