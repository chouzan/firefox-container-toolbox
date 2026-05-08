<script lang="ts">
  import ContainerList from "./ContainerList.svelte";
  import ConflictList from "./ConflictList.svelte";
  import ImportExport from "./ImportExport.svelte";
  import SettingsPanel from "./SettingsPanel.svelte";

  let containerList: ReturnType<typeof ContainerList>;
  let conflictList: ReturnType<typeof ConflictList>;

  function onImported() {
    containerList?.load();
    conflictList?.load();
  }
</script>

<div class="options">
  <header>
    <h1>Container Toolbox</h1>
    <p class="muted">Name-based container management</p>
  </header>

  <ContainerList bind:this={containerList} />
  <ConflictList bind:this={conflictList} />
  <ImportExport {onImported} />
  <SettingsPanel />
</div>

<style>
  .options {
    max-width: 640px;
    margin: 0 auto;
    padding: 24px 16px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  header {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
</style>
