let listContainers = async () => {
  await Browser.ContextualIdentities.queryAll()
}

let createContainer = async (~name: string, ~color: string, ~icon: string) => {
  try {
    await Browser.ContextualIdentities.create({"name": name, "color": color, "icon": icon})
  } catch {
  | _err => throw(Errors.make(ContainerCreateFailed, `Failed to create container "${name}"`))
  }
}

let updateContainer = async (
  cookieStoreId: string,
  updates: Browser.ContextualIdentities.updateDetails,
) => {
  await Browser.ContextualIdentities.update(cookieStoreId, updates)
}

let removeContainer = async (cookieStoreId: string) => {
  let _ = await Browser.ContextualIdentities.remove(cookieStoreId)
}

let reorderContainers = async (orderedIds: array<string>) => {
  let current = await listContainers()
  let currentIds = current->Array.map(c => c.cookieStoreId)

  let firstDiff = ref(0)
  while (
    firstDiff.contents < orderedIds->Array.length &&
    firstDiff.contents < currentIds->Array.length &&
    orderedIds->Array.getUnsafe(firstDiff.contents) ==
      currentIds->Array.getUnsafe(firstDiff.contents)
  ) {
    firstDiff := firstDiff.contents + 1
  }

  let i = ref(orderedIds->Array.length - 1)
  while i.contents >= firstDiff.contents {
    await Browser.ContextualIdentities.move(orderedIds->Array.getUnsafe(i.contents), i.contents)
    i := i.contents - 1
  }
}

let reconcile = async (desired: array<Types.containerConfig>): Types.reconcileResult => {
  NameResolver.suppressEvents()

  let actual = await listContainers()

  // Index actual by name — on duplicates, keep the first seen
  let actualByName: Dict.t<Browser.ContextualIdentities.contextualIdentity> = Dict.make()
  actual->Array.forEach(c => {
    switch actualByName->Dict.get(c.name) {
    | Some(existing) =>
      Console.warn3(
        "[container-manager] Duplicate:",
        c.name,
        `keeping ${existing.cookieStoreId}, ignoring ${c.cookieStoreId}`,
      )
    | None => actualByName->Dict.set(c.name, c)
    }
  })

  let created: array<string> = []
  let updated: array<string> = []
  let removed: array<string> = []
  let extras: array<string> = []
  let desiredNames = desired->Array.map(d => d.name)->Set.fromArray

  for idx in 0 to desired->Array.length - 1 {
    let d = desired->Array.getUnsafe(idx)
    if !(actualByName->Dict.get(d.name)->Option.isSome) {
      let c = await createContainer(
        ~name=d.name,
        ~color=(d.color :> string),
        ~icon=(d.icon :> string),
      )
      actualByName->Dict.set(d.name, c)
      created->Array.push(d.name)->ignore
    }
  }

  for idx in 0 to desired->Array.length - 1 {
    let d = desired->Array.getUnsafe(idx)
    switch actualByName->Dict.get(d.name) {
    | Some(existing) if existing.color != d.color || existing.icon != d.icon =>
      let c = await updateContainer(
        existing.cookieStoreId,
        {color: (d.color :> string), icon: (d.icon :> string)},
      )
      actualByName->Dict.set(d.name, c)
      updated->Array.push(d.name)->ignore
    | _ => ()
    }
  }

  let settings = await StorageManager.getSettings()
  let extraContainers: array<(string, Browser.ContextualIdentities.contextualIdentity)> = []
  actualByName->Dict.forEachWithKey((container, name) => {
    if !(desiredNames->Set.has(name)) {
      extras->Array.push(name)->ignore
      extraContainers->Array.push((name, container))->ignore
    }
  })

  // Handle extras sequentially (awaitable)
  for idx in 0 to extraContainers->Array.length - 1 {
    let (name, container) = extraContainers->Array.getUnsafe(idx)
    switch settings.conflictResolution {
    | ConfigWins =>
      await removeContainer(container.cookieStoreId)
      removed->Array.push(name)->ignore
    | LocalWins => ()
    | Ask =>
      let syncState = await StorageManager.getSyncState()
      let conflict: Types.syncConflict = {
        id: Browser.Crypto.randomUUID(),
        type_: "extra-container",
        description: `Container "${name}" exists locally but not in config`,
        localValue: Nullable.make({
          Types.name: container.name,
          color: (container.color :> string),
          icon: (container.icon :> string),
        }),
        remoteValue: Nullable.null,
      }
      let _ = await StorageManager.updateSyncState({
        ...syncState,
        pendingConflicts: syncState.pendingConflicts->Array.concat([conflict]),
      })
    }
  }

  let orderedIds = desired->Array.filterMap(d => {
    actualByName->Dict.get(d.name)->Option.map(c => c.cookieStoreId)
  })

  let reordered = ref(false)
  if orderedIds->Array.length > 0 {
    try {
      await reorderContainers(orderedIds)
      reordered := true
    } catch {
    | err => Console.warn2("[container-manager] Reorder failed:", err)
    }
  }

  await NameResolver.refresh()

  let currentSync = await StorageManager.getSyncState()
  let _ = await StorageManager.updateSyncState({
    ...currentSync,
    lastReconcileAt: Nullable.make(Date.make()->Date.toISOString),
  })

  {
    Types.created,
    updated,
    removed,
    reordered: reordered.contents,
    extras,
  }
}
