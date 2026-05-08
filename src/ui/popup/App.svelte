<script lang="ts">
  import {
    Action,
    sendMessage,
    shortId,
    formatReconcileResult,
    type ContainerData,
    type ReconcileResultData,
  } from "../shared/messaging.js";

  interface StatusData {
    containerCount: number;
    lastReconcileAt: string | null;
    syncEnabled: boolean;
    lastPushAt: string | null;
    lastPullAt: string | null;
    pendingConflicts: number;
  }

  let status = $state<StatusData | null>(null);
  let containers = $state<ContainerData[]>([]);
  let error = $state("");
  let reconcileLabel = $state("Reconcile");
  let reconciling = $state(false);

  function formatTime(iso: string | null): string {
    if (!iso) return "never";
    const d = new Date(iso);
    const diffMs = Date.now() - d.getTime();
    if (diffMs < 60_000) return "just now";
    if (diffMs < 3_600_000) return `${Math.floor(diffMs / 60_000)}m ago`;
    if (diffMs < 86_400_000) return `${Math.floor(diffMs / 3_600_000)}h ago`;
    return d.toLocaleDateString();
  }

  async function loadData() {
    try {
      status = await sendMessage<StatusData>(Action.getStatus);
      containers = await sendMessage<ContainerData[]>(Action.getContainers);
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to load";
    }
  }

  async function reconcile() {
    reconciling = true;
    reconcileLabel = "Reconciling...";
    try {
      const result = await sendMessage<ReconcileResultData>(
        Action.reconcileNow,
      );
      reconcileLabel = formatReconcileResult(result);
      await loadData();
    } catch (err) {
      error = err instanceof Error ? err.message : "Reconcile failed";
      reconcileLabel = "Reconcile";
    } finally {
      reconciling = false;
      setTimeout(() => (reconcileLabel = "Reconcile"), 3000);
    }
  }

  function openOptions() {
    browser.runtime.openOptionsPage();
    window.close();
  }

  loadData();
</script>

<div class="w-80 p-3 flex flex-col gap-3">
  <header>
    <h1 class="text-base font-semibold">Container Toolbox</h1>
  </header>

  <section class="flex flex-col text-sm">
    <div class="flex justify-between py-0.5">
      <span class="opacity-60">Containers</span>
      <span class="font-mono text-xs">{status?.containerCount ?? "—"}</span>
    </div>
    <div class="flex justify-between py-0.5">
      <span class="opacity-60">Last reconcile</span>
      <span class="font-mono text-xs"
        >{formatTime(status?.lastReconcileAt ?? null)}</span
      >
    </div>
    <div class="flex justify-between py-0.5">
      <span class="opacity-60">Sync</span>
      <span class="font-mono text-xs"
        >{status?.syncEnabled ? "enabled" : "off"}</span
      >
    </div>
    {#if status && status.pendingConflicts > 0}
      <div class="flex justify-between py-0.5 text-error">
        <span>Conflicts</span>
        <span class="font-mono text-xs">{status.pendingConflicts} pending</span>
      </div>
    {/if}
  </section>

  <section class="flex flex-col">
    <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60 mb-2">
      Containers
    </h2>
    {#if containers.length === 0}
      <p class="opacity-50 text-sm">No containers found.</p>
    {:else}
      <ul class="max-h-60 overflow-y-auto flex flex-col">
        {#each containers as c (c.cookieStoreId)}
          <li
            class="flex items-center gap-2 px-2 py-1 rounded hover:bg-base-300"
          >
            <div
              class="usercontext-icon"
              data-identity-icon={c.icon}
              data-identity-color={c.color}
            ></div>
            <span class="flex-1 truncate text-sm">{c.name}</span>
            <span class="font-mono text-[10px] opacity-50"
              >{shortId(c.cookieStoreId)}</span
            >
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <section class="flex gap-2">
    <button
      class="btn btn-primary btn-sm flex-1"
      disabled={reconciling}
      onclick={reconcile}
    >
      {reconcileLabel}
    </button>
    <button class="btn btn-soft btn-sm flex-1" onclick={openOptions}>
      Options
    </button>
  </section>

  {#if error}
    <div role="alert" class="alert alert-error text-sm p-2">
      {error}
    </div>
  {/if}
</div>
