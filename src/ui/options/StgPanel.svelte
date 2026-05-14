<script lang="ts">
  import { Action, sendMessage } from "../shared/messaging.js";
  import { toast } from "../shared/toast.js";

  interface Props {
    onImported?: () => void;
  }

  let { onImported }: Props = $props();

  interface ContainerMismatch {
    name: string;
    backupColor: string;
    backupIcon: string;
    localColor: string;
    localIcon: string;
  }

  interface BackupContainer {
    name: string;
    color: string;
    icon: string;
  }

  interface OrphanedTab {
    group: string;
    tab: string;
    container: string;
  }

  interface StgPreview {
    groupCount: number;
    hotkeyCount: number;
    containerCount: number;
    missingContainers: string[];
    mismatchedContainers: ContainerMismatch[];
    backupContainers: BackupContainer[];
    orphanedTabs: OrphanedTab[];
  }

  let generating = $state(false);
  let preview = $state<StgPreview | null>(null);
  let confirming = $state(false);
  let fileInput: HTMLInputElement;

  async function parseStgBackup(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const data = JSON.parse(text);
      preview = await sendMessage<StgPreview>(Action.previewStgBackup, data);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Parse failed");
    } finally {
      input.value = "";
    }
  }

  async function confirmImport(createContainers: boolean) {
    confirming = true;
    try {
      await sendMessage(Action.confirmStgImport, {
        createContainers,
        backupContainers: $state.snapshot(preview?.backupContainers ?? []),
      });
      const missing = preview?.missingContainers ?? [];
      if (createContainers && missing.length > 0) {
        toast.success(`Imported — created containers: ${missing.join(", ")}`);
      } else {
        toast.success("STG backup imported");
      }
      preview = null;
      onImported?.();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Import failed");
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
      toast.success("STG backup generated — check downloads");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Generation failed");
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
          <ul class="flex flex-col gap-1 opacity-70">
            {#each preview.missingContainers as name}
              {@const bc = preview.backupContainers.find(
                (c) => c.name === name,
              )}
              <li class="flex items-center gap-2">
                {#if bc}
                  <div
                    class="usercontext-icon"
                    data-identity-icon={bc.icon}
                    data-identity-color={bc.color}
                  ></div>
                {/if}
                <span>{name}</span>
              </li>
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
        {/if}
        {#if preview.mismatchedContainers.length > 0}
          <p class="text-info text-xs mt-1">
            {preview.mismatchedContainers.length} containers have different attributes
            locally:
          </p>
          <ul class="flex flex-col gap-1 text-xs opacity-60">
            {#each preview.mismatchedContainers as m}
              <li class="flex items-center gap-2">
                <span class="font-semibold">{m.name}</span>
                <span class="opacity-50">backup:</span>
                <div
                  class="usercontext-icon"
                  data-identity-icon={m.backupIcon}
                  data-identity-color={m.backupColor}
                ></div>
                <span class="opacity-50">local:</span>
                <div
                  class="usercontext-icon"
                  data-identity-icon={m.localIcon}
                  data-identity-color={m.localColor}
                ></div>
              </li>
            {/each}
          </ul>
        {/if}
        {#if preview.orphanedTabs.length > 0}
          <p class="text-warning text-xs mt-1">
            {preview.orphanedTabs.length} tabs had unknown container references and
            were reassigned to their group's default:
          </p>
          <ul class="flex flex-col gap-0.5 text-xs opacity-60">
            {#each preview.orphanedTabs as o}
              <li>
                <strong>{o.group}</strong>: {o.tab.slice(0, 50)}{o.tab.length >
                50
                  ? "..."
                  : ""}
                <span class="opacity-40">({o.container})</span>
              </li>
            {/each}
          </ul>
        {/if}
        {#if preview.missingContainers.length === 0}
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
  </div>
</div>
