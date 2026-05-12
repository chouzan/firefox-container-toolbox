<script lang="ts">
  import { Action, sendMessage } from "../shared/messaging.js";

  interface Props {
    onImported?: () => void;
  }

  let { onImported }: Props = $props();

  interface StgPreview {
    groupCount: number;
    hotkeyCount: number;
    containerCount: number;
    missingContainers: string[];
  }

  let statusMsg = $state("");
  let statusIsError = $state(false);
  let generating = $state(false);
  let preview = $state<StgPreview | null>(null);
  let confirming = $state(false);
  let fileInput: HTMLInputElement;

  function flash(msg: string, isError = false) {
    statusMsg = msg;
    statusIsError = isError;
    setTimeout(() => (statusMsg = ""), 5000);
  }

  async function parseStgBackup(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const data = JSON.parse(text);
      preview = await sendMessage<StgPreview>(Action.previewStgBackup, data);
    } catch (err) {
      flash(err instanceof Error ? err.message : "Parse failed", true);
    } finally {
      input.value = "";
    }
  }

  async function confirmImport(createContainers: boolean) {
    confirming = true;
    try {
      await sendMessage(Action.confirmStgImport, { createContainers });
      const missing = preview?.missingContainers ?? [];
      if (createContainers && missing.length > 0) {
        flash(`Imported — created containers: ${missing.join(", ")}`);
      } else {
        flash("STG backup imported");
      }
      preview = null;
      onImported?.();
    } catch (err) {
      flash(err instanceof Error ? err.message : "Import failed", true);
    } finally {
      confirming = false;
    }
  }

  function cancelImport() {
    preview = null;
  }

  async function generateStgBackup() {
    generating = true;
    try {
      await sendMessage(Action.generateStgBackup);
      flash("STG backup generated — check downloads");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Generation failed", true);
    } finally {
      generating = false;
    }
  }
</script>

<div class="card bg-base-200">
  <div class="card-body p-4 gap-3">
    <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">
      Simple Tab Groups
    </h2>

    {#if preview}
      <div class="flex flex-col gap-2 p-3 bg-base-300 rounded-lg text-sm">
        <p>
          <strong>{preview.groupCount}</strong> groups,
          <strong>{preview.hotkeyCount}</strong> hotkeys, referencing
          <strong>{preview.containerCount}</strong> containers.
        </p>
        {#if preview.missingContainers.length > 0}
          <p class="text-warning">
            {preview.missingContainers.length} containers don't exist locally:
          </p>
          <ul class="list-disc list-inside opacity-70">
            {#each preview.missingContainers as name}
              <li>{name}</li>
            {/each}
          </ul>
          <div class="flex gap-2 flex-wrap mt-1">
            <button
              class="btn btn-primary btn-sm"
              disabled={confirming}
              onclick={() => confirmImport(true)}
            >
              Create & Import
            </button>
            <button
              class="btn btn-soft btn-sm"
              disabled={confirming}
              onclick={() => confirmImport(false)}
            >
              Import without creating
            </button>
            <button
              class="btn btn-soft btn-sm"
              disabled={confirming}
              onclick={cancelImport}
            >
              Cancel
            </button>
          </div>
        {:else}
          <p class="text-success">All containers exist locally.</p>
          <div class="flex gap-2">
            <button
              class="btn btn-primary btn-sm"
              disabled={confirming}
              onclick={() => confirmImport(false)}
            >
              Import
            </button>
            <button
              class="btn btn-soft btn-sm"
              disabled={confirming}
              onclick={cancelImport}
            >
              Cancel
            </button>
          </div>
        {/if}
      </div>
    {:else}
      <p class="opacity-50 text-sm">
        Import an STG backup to store groups in your config. Generate an
        STG-compatible backup to restore groups on another machine.
      </p>
      <div class="flex gap-2 flex-wrap">
        <button class="btn btn-soft btn-sm" onclick={() => fileInput.click()}>
          Import STG Backup
        </button>
        <button
          class="btn btn-soft btn-sm"
          disabled={generating}
          onclick={generateStgBackup}
        >
          {generating ? "Generating..." : "Generate STG Backup"}
        </button>
      </div>
    {/if}

    <input
      type="file"
      accept=".json"
      bind:this={fileInput}
      onchange={parseStgBackup}
      hidden
    />
    {#if statusMsg}
      <p
        class="text-xs"
        class:text-success={!statusIsError}
        class:text-error={statusIsError}
      >
        {statusMsg}
      </p>
    {/if}
  </div>
</div>
