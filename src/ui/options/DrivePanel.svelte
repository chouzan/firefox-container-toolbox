<script lang="ts">
  import { Action, sendMessage } from "../shared/messaging.js";

  interface DriveStatus {
    authenticated: boolean;
    hasCredentials: boolean;
    syncEnabled: boolean;
    lastPushAt: string | null;
    lastPullAt: string | null;
    driveFileId: string | null;
  }

  interface Props {
    onSynced?: () => void;
  }

  let { onSynced }: Props = $props();

  let status = $state<DriveStatus | null>(null);
  let clientId = $state("");
  let clientSecret = $state("");
  let showCredentials = $state(false);
  let busy = $state("");
  let error = $state("");
  let success = $state("");

  function flash(msg: string, isError = false) {
    if (isError) {
      error = msg;
      success = "";
    } else {
      success = msg;
      error = "";
    }
    setTimeout(() => {
      error = "";
      success = "";
    }, 5000);
  }

  function formatTime(iso: string | null): string {
    if (!iso) return "never";
    return new Date(iso).toLocaleString();
  }

  export const load = async () => {
    try {
      status = await sendMessage<DriveStatus>(Action.driveStatus);
    } catch {
      status = null;
    }
  };

  async function saveCredentials() {
    if (!clientId.trim() || !clientSecret.trim()) {
      flash("Both fields are required", true);
      return;
    }
    try {
      busy = "Saving...";
      await sendMessage(Action.driveSetCredentials, {
        clientId: clientId.trim(),
        clientSecret: clientSecret.trim(),
      });
      showCredentials = false;
      await load();
      flash("Credentials saved");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Failed to save", true);
    } finally {
      busy = "";
    }
  }

  async function authenticate() {
    try {
      busy = "Connecting...";
      await sendMessage(Action.driveAuthenticate);
      await load();
      flash("Connected to Drive");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Auth failed", true);
    } finally {
      busy = "";
    }
  }

  async function disconnect() {
    try {
      busy = "Disconnecting...";
      await sendMessage(Action.driveRevoke);
      await load();
      flash("Disconnected");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Failed", true);
    } finally {
      busy = "";
    }
  }

  async function pull() {
    try {
      busy = "Pulling...";
      await sendMessage(Action.syncPull);
      await load();
      onSynced?.();
      flash("Pulled and reconciled");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Pull failed", true);
    } finally {
      busy = "";
    }
  }

  async function push() {
    try {
      busy = "Pushing...";
      await sendMessage(Action.syncPush);
      await load();
      flash("Pushed to Drive");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Push failed", true);
    } finally {
      busy = "";
    }
  }

  async function forcePush() {
    if (!confirm("Overwrite remote config with local state?")) return;
    try {
      busy = "Force pushing...";
      await sendMessage(Action.forcePushLocal);
      await load();
      flash("Force pushed to Drive");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Failed", true);
    } finally {
      busy = "";
    }
  }

  async function clearRemote() {
    if (!confirm("Delete config file from Drive? Local state is kept.")) return;
    try {
      busy = "Clearing...";
      await sendMessage(Action.clearRemote);
      await load();
      flash("Remote config cleared");
    } catch (err) {
      flash(err instanceof Error ? err.message : "Failed", true);
    } finally {
      busy = "";
    }
  }

  load();
</script>

<div class="card bg-base-200">
  <div class="card-body p-4 gap-3">
    <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">
      Google Drive
    </h2>

    {#if !status?.hasCredentials || showCredentials}
      <div class="flex flex-col gap-2 p-3 bg-base-300 rounded-lg">
        <p class="text-xs opacity-60">
          Enter your Google Cloud OAuth client ID and secret.
        </p>
        <input
          type="text"
          class="input input-sm input-bordered w-full"
          placeholder="Client ID"
          bind:value={clientId}
        />
        <input
          type="password"
          class="input input-sm input-bordered w-full"
          placeholder="Client Secret"
          bind:value={clientSecret}
        />
        <div class="flex gap-2 justify-end">
          <button
            class="btn btn-primary btn-xs"
            disabled={!!busy}
            onclick={saveCredentials}
          >
            {busy || "Save"}
          </button>
          {#if status?.hasCredentials}
            <button
              class="btn btn-soft btn-xs"
              onclick={() => (showCredentials = false)}
            >
              Cancel
            </button>
          {/if}
        </div>
      </div>
    {:else}
      <div class="flex flex-col gap-2 text-sm">
        <div class="flex justify-between">
          <span class="opacity-60">Status</span>
          <span
            class:text-success={status?.authenticated}
            class:text-error={!status?.authenticated}
          >
            {status?.authenticated ? "Connected" : "Not connected"}
          </span>
        </div>
        {#if status?.authenticated}
          <div class="flex justify-between">
            <span class="opacity-60">Last push</span>
            <span class="font-mono text-xs"
              >{formatTime(status.lastPushAt)}</span
            >
          </div>
          <div class="flex justify-between">
            <span class="opacity-60">Last pull</span>
            <span class="font-mono text-xs"
              >{formatTime(status.lastPullAt)}</span
            >
          </div>
        {/if}
      </div>

      <div class="flex gap-2 flex-wrap">
        {#if !status?.authenticated}
          <button
            class="btn btn-primary btn-sm"
            disabled={!!busy}
            onclick={authenticate}
          >
            {busy || "Connect"}
          </button>
        {:else}
          <button
            class="btn btn-primary btn-sm"
            disabled={!!busy}
            onclick={pull}
          >
            {busy === "Pulling..." ? busy : "Pull"}
          </button>
          <button class="btn btn-soft btn-sm" disabled={!!busy} onclick={push}>
            {busy === "Pushing..." ? busy : "Push"}
          </button>
          <button
            class="btn btn-soft btn-sm"
            disabled={!!busy}
            onclick={forcePush}
          >
            Force Push
          </button>
          <button
            class="btn btn-error btn-outline btn-sm"
            disabled={!!busy}
            onclick={clearRemote}
          >
            Clear Remote
          </button>
          <button
            class="btn btn-soft btn-sm"
            disabled={!!busy}
            onclick={disconnect}
          >
            Disconnect
          </button>
        {/if}
        <button
          class="btn btn-soft btn-xs"
          onclick={() => (showCredentials = true)}
        >
          Credentials
        </button>
      </div>
    {/if}

    {#if error}
      <p class="text-xs text-error">{error}</p>
    {/if}
    {#if success}
      <p class="text-xs text-success">{success}</p>
    {/if}
  </div>
</div>
