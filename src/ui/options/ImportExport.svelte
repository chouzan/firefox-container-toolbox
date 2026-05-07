<script lang="ts">
  import type {
    containerToolboxConfig,
    reconcileResult,
  } from "../../lib/Types.gen";
  import { sendMessage } from "../shared/messaging.js";

  interface Props {
    onImported?: () => void;
  }

  let { onImported }: Props = $props();

  let statusMsg = $state("");
  let statusIsError = $state(false);
  let reconciling = $state(false);
  let fileInput: HTMLInputElement;

  function flash(msg: string, isError = false) {
    statusMsg = msg;
    statusIsError = isError;
    setTimeout(() => (statusMsg = ""), 4000);
  }

  async function exportConfig() {
    try {
      const config = await sendMessage<containerToolboxConfig>("EXPORT_CONFIG");
      const blob = new Blob([JSON.stringify(config, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `container-toolbox-config-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      flash("Config exported");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Export failed", true);
    }
  }

  async function handleFile(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const data = JSON.parse(text);
      const result = await sendMessage<reconcileResult>("IMPORT_CONFIG", data);

      const parts: string[] = [];
      if (result.created.length) parts.push(`${result.created.length} created`);
      if (result.updated.length) parts.push(`${result.updated.length} updated`);
      if (result.removed.length) parts.push(`${result.removed.length} removed`);
      flash(
        parts.length
          ? `Imported: ${parts.join(", ")}`
          : "Imported (no changes)",
      );

      onImported?.();
    } catch (err) {
      flash(err instanceof Error ? err.message : "Import failed", true);
    } finally {
      input.value = "";
    }
  }

  async function reconcile() {
    reconciling = true;
    try {
      const result = await sendMessage<reconcileResult>("RECONCILE_NOW");
      const parts: string[] = [];
      if (result.created.length) parts.push(`${result.created.length} created`);
      if (result.updated.length) parts.push(`${result.updated.length} updated`);
      if (result.removed.length) parts.push(`${result.removed.length} removed`);
      flash(parts.length ? parts.join(", ") : "No changes needed");
      onImported?.();
    } catch (err) {
      flash(err instanceof Error ? err.message : "Reconcile failed", true);
    } finally {
      reconciling = false;
    }
  }
</script>

<section class="card">
  <h2>Import / Export</h2>
  <div class="btn-group">
    <button class="btn btn-secondary" onclick={exportConfig}
      >Export Config</button
    >
    <button class="btn btn-secondary" onclick={() => fileInput.click()}
      >Import Config</button
    >
    <button class="btn btn-primary" disabled={reconciling} onclick={reconcile}>
      {reconciling ? "Reconciling..." : "Reconcile"}
    </button>
  </div>
  <input
    type="file"
    accept=".json"
    bind:this={fileInput}
    onchange={handleFile}
    hidden
  />
  {#if statusMsg}
    <p class="status-msg" class:error={statusIsError}>{statusMsg}</p>
  {/if}
</section>

<style>
  .btn-group {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }

  .status-msg {
    font-size: 12px;
    color: var(--success);
  }
  .status-msg.error {
    color: var(--danger);
  }
</style>
