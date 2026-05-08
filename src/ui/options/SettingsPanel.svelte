<script lang="ts">
  import type { settings } from "../../lib/Types.gen";
  import { defaultConflictResolution } from "../../lib/Constants.gen";
  import type { conflictResolution as ConflictResolution } from "../../lib/Constants.gen";
  import { Action, sendMessage } from "../shared/messaging.js";

  const conflictOptions: { value: ConflictResolution; label: string }[] = [
    { value: "local-wins", label: "Local wins (keep extra containers)" },
    { value: "config-wins", label: "Config wins (remove extras)" },
    { value: "ask", label: "Ask each time" },
  ];

  let conflictResolution = $state(defaultConflictResolution);
  let error = $state("");

  async function loadSettings() {
    try {
      const s = await sendMessage<settings>(Action.getSettings);
      conflictResolution = s.conflictResolution;
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to load settings";
    }
  }

  async function onConflictChange() {
    try {
      await sendMessage(Action.updateSettings, { conflictResolution });
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
      {#each conflictOptions as opt}
        <option value={opt.value}>{opt.label}</option>
      {/each}
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
