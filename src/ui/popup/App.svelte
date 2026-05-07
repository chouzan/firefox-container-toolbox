<script lang="ts">
  import { sendMessage } from "../shared/messaging.js";

  interface StatusData {
    containerCount: number;
    lastReconcileAt: string | null;
    syncEnabled: boolean;
    lastPushAt: string | null;
    lastPullAt: string | null;
    pendingConflicts: number;
  }

  interface ContainerData {
    cookieStoreId: string;
    name: string;
    color: string;
    icon: string;
    resolvedName: string;
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

  function shortId(id: string): string {
    const match = id.match(/firefox-container-(\d+)/);
    return match ? `ct-${match[1]}` : id;
  }

  async function loadData() {
    try {
      status = await sendMessage<StatusData>("GET_STATUS");
      containers = await sendMessage<ContainerData[]>("GET_CONTAINERS");
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to load";
    }
  }

  async function reconcile() {
    reconciling = true;
    reconcileLabel = "Reconciling...";
    try {
      const result = await sendMessage<{
        created: string[];
        updated: string[];
        removed: string[];
      }>("RECONCILE_NOW");
      const parts: string[] = [];
      if (result.created.length) parts.push(`+${result.created.length}`);
      if (result.updated.length) parts.push(`~${result.updated.length}`);
      if (result.removed.length) parts.push(`-${result.removed.length}`);
      reconcileLabel = parts.length ? parts.join(" ") : "No changes";
      await loadData();
    } catch (err) {
      error = err instanceof Error ? err.message : "Reconcile failed";
      reconcileLabel = "Reconcile";
    } finally {
      reconciling = false;
      setTimeout(() => (reconcileLabel = "Reconcile"), 2000);
    }
  }

  function openOptions() {
    browser.runtime.openOptionsPage();
    window.close();
  }

  loadData();
</script>

<div class="popup">
  <header class="popup-header">
    <h1>Container Toolbox</h1>
  </header>

  <section class="section">
    <div class="status-row">
      <span class="label">Containers</span>
      <span class="value">{status?.containerCount ?? "—"}</span>
    </div>
    <div class="status-row">
      <span class="label">Last reconcile</span>
      <span class="value">{formatTime(status?.lastReconcileAt ?? null)}</span>
    </div>
    <div class="status-row">
      <span class="label">Sync</span>
      <span class="value">{status?.syncEnabled ? "enabled" : "off"}</span>
    </div>
  </section>

  <section class="section">
    <h2>Containers</h2>
    {#if containers.length === 0}
      <p class="muted">No containers found.</p>
    {:else}
      <ul id="containers">
        {#each containers as c (c.cookieStoreId)}
          <li class="container-item">
            <div
              class="usercontext-icon"
              data-identity-icon={c.icon}
              data-identity-color={c.color}
            ></div>
            <span class="container-name">{c.name}</span>
            <span class="container-id">{shortId(c.cookieStoreId)}</span>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <section class="section actions">
    <button class="btn btn-primary" disabled={reconciling} onclick={reconcile}>
      {reconcileLabel}
    </button>
    <button class="btn btn-secondary" onclick={openOptions}> Options </button>
  </section>

  {#if error}
    <div class="error-banner">{error}</div>
  {/if}
</div>

<style>
  .popup {
    width: 320px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .popup-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .section {
    display: flex;
    flex-direction: column;
  }

  .status-row {
    display: flex;
    justify-content: space-between;
    padding: 3px 0;
  }
  .status-row .label {
    color: var(--text-muted);
  }
  .status-row .value {
    font-family: var(--font-mono);
    font-size: 12px;
  }

  #containers {
    list-style: none;
    max-height: 240px;
    overflow-y: auto;
  }

  .container-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 5px 8px;
    border-radius: var(--radius);
  }
  .container-item:hover {
    background: var(--bg-surface);
  }

  .container-name {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .container-id {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--text-muted);
    white-space: nowrap;
  }

  .actions {
    flex-direction: row;
    gap: 8px;
  }
  .actions :global(.btn) {
    flex: 1;
  }
</style>
