<script lang="ts">
  import type { containerToolboxConfig } from "../../lib/Types.gen";
  import {
    Action,
    sendMessage,
    formatReconcileResult,
    type ReconcileResultData,
  } from "../shared/messaging.js";
  import { toast } from "../shared/toast.js";

  interface Props {
    onImported?: () => void;
  }

  let { onImported }: Props = $props();

  let reconciling = $state(false);
  let fileInput: HTMLInputElement;

  async function exportConfig() {
    try {
      const config = await sendMessage<containerToolboxConfig>(
        Action.exportConfig,
      );
      const blob = new Blob([JSON.stringify(config, null, 2)], {
        type: "application/json",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `container-toolbox-config-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success("Config exported");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Export failed");
    }
  }

  async function handleFile(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const data = JSON.parse(text);
      const result = await sendMessage<ReconcileResultData>(
        Action.importConfig,
        data,
      );
      toast.success(`Imported: ${formatReconcileResult(result)}`);
      onImported?.();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Import failed");
    } finally {
      input.value = "";
    }
  }

  async function reconcile() {
    reconciling = true;
    try {
      const result = await sendMessage<ReconcileResultData>(
        Action.reconcileNow,
      );
      toast.success(formatReconcileResult(result));
      onImported?.();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Reconcile failed");
    } finally {
      reconciling = false;
    }
  }
</script>

<div class="card bg-base-200">
  <div class="card-body p-4 gap-3">
    <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">
      Import / Export
    </h2>
    <div class="flex gap-2 flex-wrap">
      <button class="btn btn-soft btn-sm" onclick={exportConfig}
        >Export Config</button
      >
      <button class="btn btn-soft btn-sm" onclick={() => fileInput.click()}
        >Import Config</button
      >
      <button
        class="btn btn-primary btn-sm"
        disabled={reconciling}
        onclick={reconcile}
      >
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
  </div>
</div>
