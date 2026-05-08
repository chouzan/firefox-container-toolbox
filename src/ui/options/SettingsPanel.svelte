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

<div class="card bg-base-200">
  <div class="card-body p-4 gap-3">
    <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">
      Settings
    </h2>
    <div class="flex justify-between items-center gap-4">
      <label for="conflict-resolution" class="text-sm whitespace-nowrap"
        >Conflict resolution</label
      >
      <select
        id="conflict-resolution"
        class="select select-sm select-bordered flex-1 max-w-72"
        bind:value={conflictResolution}
        onchange={onConflictChange}
      >
        {#each conflictOptions as opt}
          <option value={opt.value}>{opt.label}</option>
        {/each}
      </select>
    </div>
    {#if error}
      <p class="text-xs text-error">{error}</p>
    {/if}
  </div>
</div>
