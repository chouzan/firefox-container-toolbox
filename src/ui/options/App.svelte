<script lang="ts">
  import ContainerList from "./ContainerList.svelte";
  import ConflictList from "./ConflictList.svelte";
  import ImportExport from "./ImportExport.svelte";
  import StgPanel from "./StgPanel.svelte";
  import DrivePanel from "./DrivePanel.svelte";
  import SettingsPanel from "./SettingsPanel.svelte";

  let containerList: ReturnType<typeof ContainerList>;
  let conflictList: ReturnType<typeof ConflictList>;

  function onImported() {
    containerList?.load();
    conflictList?.load();
  }
</script>

<div class="max-w-2xl mx-auto p-6 flex flex-col gap-5">
  <header class="flex flex-col gap-1">
    <h1 class="text-lg font-semibold">Container Toolbox</h1>
    <p class="opacity-50 text-sm">Name-based container management</p>
  </header>

  <ContainerList bind:this={containerList} />
  <ConflictList bind:this={conflictList} />
  <ImportExport {onImported} />
  <StgPanel {onImported} />
  <DrivePanel onSynced={onImported} />
  <SettingsPanel />
</div>
