<script lang="ts">
  import type { settings } from "../../lib/Types.gen";
  import { sendMessage } from "../shared/messaging.js";

  let conflictResolution = $state("local-wins");
  let error = $state("");

  async function loadSettings() {
    try {
      const s = await sendMessage<settings>("GET_SETTINGS");
      conflictResolution = s.conflictResolution;
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to load settings";
    }
  }

  async function onConflictChange(e: Event) {
    const value = (e.target as HTMLSelectElement).value;
    conflictResolution = value;
    try {
      await sendMessage("UPDATE_SETTINGS", { conflictResolution: value });
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to save";
    }
  }

  loadSettings();
</script>

<section class="card">
  <h2>Settings</h2>
  <div class="setting-row">
    <label for="conflict-resolution">Conflict resolution</label>
    <select
      id="conflict-resolution"
      bind:value={conflictResolution}
      onchange={onConflictChange}
    >
      <option value="local-wins">Local wins (keep extra containers)</option>
      <option value="config-wins">Config wins (remove extras)</option>
      <option value="ask">Ask each time</option>
    </select>
  </div>
  {#if error}
    <p class="error-msg">{error}</p>
  {/if}
</section>

<style>
  .setting-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
  }
  .setting-row label {
    white-space: nowrap;
  }
  .setting-row select {
    flex: 1;
    max-width: 280px;
  }
  .error-msg {
    font-size: 12px;
    color: var(--danger);
  }
</style>
