<script lang="ts">
  import {
    containerColors,
    containerIcons,
    defaultColor,
    defaultIcon,
  } from "../../lib/Constants.gen";
  import {
    Action,
    sendMessage,
    shortId,
    type ContainerData,
  } from "../shared/messaging.js";

  let containers = $state<ContainerData[]>([]);
  let showForm = $state(false);
  let editingId = $state<string | null>(null);
  let formName = $state("");
  let selectedColor = $state(defaultColor);
  let selectedIcon = $state(defaultIcon);
  let statusMsg = $state("");
  let statusIsError = $state(false);

  let draggedIdx = $state<number | null>(null);
  let dragOverIdx = $state<number | null>(null);
  let moving = $state(false);

  function flash(msg: string, isError = false) {
    statusMsg = msg;
    statusIsError = isError;
    setTimeout(() => (statusMsg = ""), 4000);
  }

  export const load = async () => {
    try {
      containers = await sendMessage<ContainerData[]>(Action.getContainers);
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
    selectedColor = defaultColor;
    selectedIcon = defaultIcon;
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
        await sendMessage(Action.updateContainer, {
          cookieStoreId: editingId,
          updates: { name, color: selectedColor, icon: selectedIcon },
        });
      } else {
        await sendMessage(Action.createContainer, {
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
      await sendMessage(Action.deleteContainer, {
        cookieStoreId: c.cookieStoreId,
      });
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
      await sendMessage(Action.moveContainer, {
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

<div class="card bg-base-200">
  <div class="card-body p-4 gap-3">
    <div class="flex justify-between items-center">
      <h2 class="text-xs font-semibold uppercase tracking-wide opacity-60">
        Containers
      </h2>
      <button class="btn btn-primary btn-xs" onclick={openAdd}>Add</button>
    </div>

    {#if containers.length === 0 && !showForm}
      <p class="opacity-50 text-sm">
        No containers. Add one or import a config.
      </p>
    {/if}

    <ul class="flex flex-col gap-0.5">
      {#each containers as c, i (c.cookieStoreId)}
        <li
          class="flex items-center gap-2.5 px-2 py-1.5 rounded hover:bg-base-300 group"
          class:opacity-40={draggedIdx === i}
          class:border-t-2={dragOverIdx === i}
          class:border-primary={dragOverIdx === i}
          ondragover={(e) => onDragOver(e, i)}
          ondragleave={onDragLeave}
          ondrop={(e) => onDrop(e, i)}
        >
          <div
            class="usercontext-icon"
            data-identity-icon={c.icon}
            data-identity-color={c.color}
          ></div>
          <span class="flex-1 text-sm">{c.name}</span>
          <span class="font-mono text-[11px] opacity-40"
            >{shortId(c.cookieStoreId)}</span
          >
          <span
            class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
          >
            <button class="btn btn-soft btn-xs" onclick={() => openEdit(c)}
              >Edit</button
            >
            <button
              class="btn btn-error btn-outline btn-xs"
              onclick={() => deleteContainer(c)}>Del</button
            >
          </span>
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <span
            class="flex flex-col gap-0.5 cursor-grab px-0.5 opacity-20 group-hover:opacity-60 transition-opacity"
            role="button"
            tabindex="0"
            draggable="true"
            title="Drag to reorder"
            ondragstart={(e) => onGripDragStart(e, i)}
            ondragend={onDragEnd}
          >
            <span class="w-2.5 h-0.5 bg-current rounded-sm"></span>
            <span class="w-2.5 h-0.5 bg-current rounded-sm"></span>
            <span class="w-2.5 h-0.5 bg-current rounded-sm"></span>
          </span>
        </li>
      {/each}
    </ul>

    {#if showForm}
      <div class="flex flex-col gap-2.5 p-3 bg-base-300 rounded-lg">
        <input
          type="text"
          class="input input-sm input-bordered w-full"
          placeholder="Container name"
          bind:value={formName}
          onkeydown={onFormKeydown}
        />
        <div class="flex flex-col gap-1.5">
          <span
            class="text-[11px] font-semibold uppercase tracking-wide opacity-50"
            >Colour</span
          >
          <div class="flex flex-wrap gap-1">
            {#each containerColors as color}
              <button
                type="button"
                class="w-8 h-8 flex items-center justify-center rounded border-2 p-0 cursor-pointer transition-colors"
                class:border-primary={selectedColor === color}
                class:border-transparent={selectedColor !== color}
                class:bg-base-100={selectedColor === color}
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
        <div class="flex flex-col gap-1.5">
          <span
            class="text-[11px] font-semibold uppercase tracking-wide opacity-50"
            >Icon</span
          >
          <div class="flex flex-wrap gap-1">
            {#each containerIcons as icon}
              <button
                type="button"
                class="w-8 h-8 flex items-center justify-center rounded border-2 p-0 cursor-pointer transition-colors"
                class:border-primary={selectedIcon === icon}
                class:border-transparent={selectedIcon !== icon}
                class:bg-base-100={selectedIcon === icon}
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
        <div class="flex gap-2 justify-end">
          <button class="btn btn-primary btn-xs" onclick={saveForm}>Save</button
          >
          <button class="btn btn-soft btn-xs" onclick={closeForm}>Cancel</button
          >
        </div>
      </div>
    {/if}

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
