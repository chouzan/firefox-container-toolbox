<script lang="ts">
  import { containerColors, containerIcons } from "../../lib/Constants.gen";
  import { sendMessage } from "../shared/messaging.js";

  interface ContainerData {
    cookieStoreId: string;
    name: string;
    color: string;
    icon: string;
    resolvedName: string;
  }

  let containers = $state<ContainerData[]>([]);
  let showForm = $state(false);
  let editingId = $state<string | null>(null);
  let formName = $state("");
  let selectedColor = $state("blue");
  let selectedIcon = $state("fingerprint");
  let statusMsg = $state("");
  let statusIsError = $state(false);

  // Drag state
  let draggedIdx = $state<number | null>(null);
  let dragOverIdx = $state<number | null>(null);
  let moving = $state(false);

  function shortId(id: string): string {
    const match = id.match(/firefox-container-(\d+)/);
    return match ? `ct-${match[1]}` : id;
  }

  function flash(msg: string, isError = false) {
    statusMsg = msg;
    statusIsError = isError;
    setTimeout(() => (statusMsg = ""), 4000);
  }

  export const load = async () => {
    try {
      containers = await sendMessage<ContainerData[]>("GET_CONTAINERS");
    } catch (err) {
      flash(
        err instanceof Error ? err.message : "Failed to load containers",
        true,
      );
    }
  };

  function openAdd() {
    editingId = null;
    formName = "";
    selectedColor = "blue";
    selectedIcon = "fingerprint";
    showForm = true;
  }

  function openEdit(c: ContainerData) {
    editingId = c.cookieStoreId;
    formName = c.name;
    selectedColor = c.color;
    selectedIcon = c.icon;
    showForm = true;
  }

  function closeForm() {
    showForm = false;
    editingId = null;
  }

  async function saveForm() {
    const name = formName.trim();
    if (!name) {
      flash("Name is required", true);
      return;
    }

    try {
      if (editingId) {
        await sendMessage("UPDATE_CONTAINER", {
          cookieStoreId: editingId,
          updates: { name, color: selectedColor, icon: selectedIcon },
        });
      } else {
        await sendMessage("CREATE_CONTAINER", {
          name,
          color: selectedColor,
          icon: selectedIcon,
        });
      }
      closeForm();
      await load();
    } catch (err) {
      flash(err instanceof Error ? err.message : "Save failed", true);
    }
  }

  async function deleteContainer(c: ContainerData) {
    if (
      !confirm(
        `Remove container "${c.name}"? Tabs in this container will be closed.`,
      )
    )
      return;
    try {
      await sendMessage("DELETE_CONTAINER", { cookieStoreId: c.cookieStoreId });
      await load();
    } catch (err) {
      flash(err instanceof Error ? err.message : "Delete failed", true);
    }
  }

  function onGripDragStart(e: DragEvent, idx: number) {
    if (moving) {
      e.preventDefault();
      return;
    }
    draggedIdx = idx;
    e.dataTransfer!.effectAllowed = "move";
  }

  function onDragOver(e: DragEvent, idx: number) {
    e.preventDefault();
    e.dataTransfer!.dropEffect = "move";
    dragOverIdx = idx;
  }

  function onDragLeave() {
    dragOverIdx = null;
  }

  async function onDrop(e: DragEvent, toIdx: number) {
    e.preventDefault();
    dragOverIdx = null;
    if (draggedIdx === null || draggedIdx === toIdx) return;

    const item = containers[draggedIdx];
    const updated = [...containers];
    updated.splice(draggedIdx, 1);
    updated.splice(toIdx, 0, item);
    containers = updated;
    draggedIdx = null;

    try {
      moving = true;
      await sendMessage("MOVE_CONTAINER", {
        cookieStoreId: item.cookieStoreId,
        position: toIdx,
      });
    } catch (err) {
      flash(err instanceof Error ? err.message : "Reorder failed", true);
      await load();
    } finally {
      moving = false;
    }
  }

  function onDragEnd() {
    draggedIdx = null;
    dragOverIdx = null;
  }

  function onFormKeydown(e: KeyboardEvent) {
    if (e.key === "Enter") saveForm();
    if (e.key === "Escape") closeForm();
  }

  load();
</script>

<section class="card">
  <div class="card-header">
    <h2>Containers</h2>
    <button class="btn btn-primary btn-sm" onclick={openAdd}>Add</button>
  </div>

  {#if containers.length === 0 && !showForm}
    <p class="muted">No containers. Add one or import a config.</p>
  {/if}

  <ul class="item-list">
    {#each containers as c, i (c.cookieStoreId)}
      <li
        class="container-row"
        class:dragging={draggedIdx === i}
        class:drag-over={dragOverIdx === i}
        ondragover={(e) => onDragOver(e, i)}
        ondragleave={onDragLeave}
        ondrop={(e) => onDrop(e, i)}
      >
        <div
          class="usercontext-icon"
          data-identity-icon={c.icon}
          data-identity-color={c.color}
        ></div>
        <span class="name">{c.name}</span>
        <span class="id">{shortId(c.cookieStoreId)}</span>
        <span class="row-actions">
          <button class="btn btn-secondary btn-sm" onclick={() => openEdit(c)}
            >Edit</button
          >
          <button
            class="btn btn-danger btn-sm"
            onclick={() => deleteContainer(c)}>Del</button
          >
        </span>
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <span
          class="drag-grip"
          role="button"
          tabindex="0"
          draggable="true"
          title="Drag to reorder"
          ondragstart={(e) => onGripDragStart(e, i)}
          ondragend={onDragEnd}
        ></span>
      </li>
    {/each}
  </ul>

  {#if showForm}
    <div class="container-form">
      <div class="form-row">
        <input
          type="text"
          class="form-name-input"
          placeholder="Container name"
          bind:value={formName}
          onkeydown={onFormKeydown}
        />
      </div>
      <div class="form-row">
        <span class="form-label">Color</span>
        <div class="picker-grid">
          {#each containerColors as color}
            <button
              type="button"
              class="picker-option"
              class:selected={selectedColor === color}
              title={color}
              onclick={() => (selectedColor = color)}
            >
              <div
                class="usercontext-icon"
                data-identity-icon="circle"
                data-identity-color={color}
              ></div>
            </button>
          {/each}
        </div>
      </div>
      <div class="form-row">
        <span class="form-label">Icon</span>
        <div class="picker-grid">
          {#each containerIcons as icon}
            <button
              type="button"
              class="picker-option"
              class:selected={selectedIcon === icon}
              title={icon}
              onclick={() => (selectedIcon = icon)}
            >
              <div
                class="usercontext-icon"
                data-identity-icon={icon}
                data-identity-color="toolbar"
              ></div>
            </button>
          {/each}
        </div>
      </div>
      <div class="form-actions">
        <button class="btn btn-primary btn-sm" onclick={saveForm}>Save</button>
        <button class="btn btn-secondary btn-sm" onclick={closeForm}
          >Cancel</button
        >
      </div>
    </div>
  {/if}

  {#if statusMsg}
    <p class="status-msg" class:error={statusIsError}>{statusMsg}</p>
  {/if}
</section>

<style>
  .item-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .container-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 8px;
    border-radius: var(--radius);
  }
  .container-row:hover {
    background: var(--bg-hover);
  }
  .container-row.dragging {
    opacity: 0.4;
  }
  .container-row.drag-over {
    border-top: 2px solid var(--accent);
  }

  .container-row .name {
    flex: 1;
  }
  .container-row .id {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--text-muted);
  }

  .row-actions {
    display: flex;
    gap: 4px;
    opacity: 0;
    transition: opacity 0.15s;
  }
  .container-row:hover .row-actions {
    opacity: 1;
  }

  .drag-grip {
    display: flex;
    flex-direction: column;
    gap: 2px;
    cursor: grab;
    padding: 4px 2px;
    opacity: 0.3;
    transition: opacity 0.15s;
  }
  .container-row:hover .drag-grip {
    opacity: 0.7;
  }
  .drag-grip::before,
  .drag-grip::after {
    content: "";
    display: block;
    width: 10px;
    height: 2px;
    background: var(--text-muted);
    border-radius: 1px;
  }
  .drag-grip::before {
    box-shadow: 0 4px 0 var(--text-muted);
  }

  .container-form {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 12px;
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius);
  }

  .form-row {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .form-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .form-name-input {
    width: 100%;
  }

  .picker-grid {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }

  .picker-option {
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: var(--radius);
    border: 2px solid transparent;
    background: transparent;
    cursor: pointer;
    padding: 0;
    transition:
      border-color 0.12s,
      background 0.12s;
  }
  .picker-option:hover {
    background: var(--bg-hover);
  }
  .picker-option.selected {
    border-color: var(--accent);
    background: rgba(0, 221, 255, 0.1);
  }

  .form-actions {
    display: flex;
    gap: 8px;
    justify-content: flex-end;
  }

  .status-msg {
    font-size: 12px;
    color: var(--success);
  }
  .status-msg.error {
    color: var(--danger);
  }
</style>
