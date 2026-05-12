type okResponse = {ok: bool}

type statusResponse = {
  containerCount: int,
  lastReconcileAt: Nullable.t<string>,
  lastPushAt: Nullable.t<string>,
  lastPullAt: Nullable.t<string>,
  syncEnabled: bool,
  pendingConflicts: int,
}

type containerResponse = {
  cookieStoreId: string,
  name: string,
  color: Constants.containerColor,
  icon: Constants.containerIcon,
  resolvedName: string,
}

type createPayload = {name: string, color: string, icon: string}
type updatePayload = {cookieStoreId: string, updates: Browser.ContextualIdentities.updateDetails}
type deletePayload = {cookieStoreId: string}
type movePayload = {cookieStoreId: string, position: int}

MessageRouter.handleUnit(Constants.action["getStatus"], async () => {
  let containers = await ContainerManager.listContainers()
  let syncState = await StorageManager.getSyncState()
  let settings = await StorageManager.getSettings()
  {
    containerCount: containers->Array.length,
    lastReconcileAt: syncState.lastReconcileAt,
    lastPushAt: syncState.lastPushAt,
    lastPullAt: syncState.lastPullAt,
    syncEnabled: settings.syncEnabled,
    pendingConflicts: syncState.pendingConflicts->Array.length,
  }
})

MessageRouter.handleUnit(Constants.action["getContainers"], async () => {
  let containers = await ContainerManager.listContainers()
  let idToName = NameResolver.getIdToName()
  containers->Array.map(c => {
    {
      cookieStoreId: c.cookieStoreId,
      name: c.name,
      color: c.color,
      icon: c.icon,
      resolvedName: idToName->Dict.get(c.cookieStoreId)->Option.getOr(c.name),
    }
  })
})

MessageRouter.handleUnit(Constants.action["getSettings"], async () => {
  await StorageManager.getSettings()
})

MessageRouter.handle(Constants.action["updateSettings"], async (payload: JSON.t) => {
  await StorageManager.updatePartialSettings(payload)
})

MessageRouter.handle(Constants.action["createContainer"], async (p: createPayload) => {
  await ContainerManager.createContainer(~name=p.name, ~color=p.color, ~icon=p.icon)
})

MessageRouter.handle(Constants.action["updateContainer"], async (p: updatePayload) => {
  await ContainerManager.updateContainer(p.cookieStoreId, p.updates)
})

MessageRouter.handle(Constants.action["deleteContainer"], async (p: deletePayload) => {
  await ContainerManager.removeContainer(p.cookieStoreId)
  {ok: true}
})

MessageRouter.handle(Constants.action["moveContainer"], async (p: movePayload) => {
  await Browser.ContextualIdentities.move(p.cookieStoreId, p.position)
  {ok: true}
})

MessageRouter.handleUnit(Constants.action["reconcileNow"], async () => {
  let lastConfig = await StorageManager.getLastConfig()
  switch lastConfig->Nullable.toOption {
  | None => throw(Errors.make(ConfigInvalid, "No config loaded — import or pull a config first"))
  | Some(config) => await ContainerManager.reconcile(config.containers)
  }
})

MessageRouter.handleUnit(Constants.action["exportConfig"], async () => {
  let containers = await ContainerManager.listContainers()
  let lastConfig = await StorageManager.getLastConfig()
  let prev = lastConfig->Nullable.toOption
  let config: Types.containerToolboxConfig = {
    version: 1,
    meta: {
      exportedAt: Date.make()->Date.toISOString,
      exportedFrom: `container-toolbox@${Constants.extensionVersion}`,
    },
    containers: containers->Array.mapWithIndex((c, i) => {
      {
        Types.name: c.name,
        color: c.color,
        icon: c.icon,
        order: i,
      }
    }),
    stgGroups: prev->Option.map(p => p.stgGroups)->Option.getOr([]),
    stgHotkeys: prev->Option.map(p => p.stgHotkeys)->Option.getOr([]),
    stgDefaultGroupProps: prev
    ->Option.map(p => p.stgDefaultGroupProps)
    ->Option.getOr({
      prependTitleToWindow: false,
      showNotificationAfterMovingTabIntoThisGroup: false,
    }),
  }
  await StorageManager.setLastConfig(Nullable.make(config))
  config
})

MessageRouter.handle(Constants.action["importConfig"], async (payload: JSON.t) => {
  if !Validators.validateConfig(payload) {
    throw(Errors.make(ConfigInvalid, "Invalid config format"))
  }
  // Validated — safe to treat as typed
  let config: Types.containerToolboxConfig = Obj.magic(payload)
  await StorageManager.setLastConfig(Nullable.make(config))
  await ContainerManager.reconcile(config.containers)
})

type credentialsPayload = {clientId: string, clientSecret: string}

MessageRouter.handleUnit(Constants.action["driveAuthenticate"], async () => {
  await DriveClient.authenticate()
  {ok: true}
})

MessageRouter.handleUnit(Constants.action["driveRevoke"], async () => {
  await DriveClient.revokeAuth()
  {ok: true}
})

MessageRouter.handleUnit(Constants.action["driveStatus"], async () => {
  let auth = await StorageManager.getDriveAuth()
  let syncState = await StorageManager.getSyncState()
  let settings = await StorageManager.getSettings()
  {
    "authenticated": auth.accessToken->Nullable.toOption->Option.isSome,
    "hasCredentials": auth.clientId->Nullable.toOption->Option.isSome,
    "syncEnabled": settings.syncEnabled,
    "lastPushAt": syncState.lastPushAt,
    "lastPullAt": syncState.lastPullAt,
    "driveFileId": settings.driveFileId,
  }
})

MessageRouter.handle(Constants.action["driveSetCredentials"], async (p: credentialsPayload) => {
  let auth = await StorageManager.getDriveAuth()
  await StorageManager.setDriveAuth({
    ...auth,
    clientId: Nullable.make(p.clientId),
    clientSecret: Nullable.make(p.clientSecret),
  })
  {ok: true}
})

MessageRouter.handleUnit(Constants.action["syncPull"], async () => {
  await SyncEngine.pullAndApply()
})

MessageRouter.handleUnit(Constants.action["syncPush"], async () => {
  await SyncEngine.exportAndPush()
})

MessageRouter.handleUnit(Constants.action["forcePushLocal"], async () => {
  await SyncEngine.forcePushLocal()
})

MessageRouter.handleUnit(Constants.action["clearRemote"], async () => {
  await SyncEngine.clearRemote()
  {ok: true}
})

// Step 1: Parse, store, and preview — returns group count and missing containers
MessageRouter.handle(Constants.action["previewStgBackup"], async (payload: JSON.t) => {
  switch StgBridge.parseBackup(payload) {
  | None => throw(Errors.make(StgBackupParseFailed, "Invalid STG backup format"))
  | Some(parsed) =>
    // Merge STG data into stored config
    let lastConfig = await StorageManager.getLastConfig()
    let config = switch lastConfig->Nullable.toOption {
    | Some(prev) => {
        ...prev,
        stgGroups: parsed.stgGroups,
        stgHotkeys: parsed.stgHotkeys,
        stgDefaultGroupProps: parsed.stgDefaultGroupProps,
        meta: {
          exportedAt: Date.make()->Date.toISOString,
          exportedFrom: `container-toolbox@${Constants.extensionVersion}`,
        },
      }
    | None => parsed
    }
    await StorageManager.setLastConfig(Nullable.make(config))

    let referencedNames = StgBridge.extractContainerNames(parsed.stgGroups)
    let existingContainers = await ContainerManager.listContainers()
    let existingNames = existingContainers->Array.map(c => c.name)->Set.fromArray
    let missingContainers = referencedNames->Array.filter(n => !(existingNames->Set.has(n)))

    {
      "groupCount": parsed.stgGroups->Array.length,
      "hotkeyCount": parsed.stgHotkeys->Array.length,
      "containerCount": referencedNames->Array.length,
      "missingContainers": missingContainers,
    }
  }
})

type confirmPayload = {createContainers: bool}

// Step 2: Confirm — import with or without creating missing containers
MessageRouter.handle(Constants.action["confirmStgImport"], async (p: confirmPayload) => {
  let lastConfig = await StorageManager.getLastConfig()

  // Re-parse from stored config (preview already validated)
  let config = switch lastConfig->Nullable.toOption {
  | None => throw(Errors.make(ConfigInvalid, "No config — run preview first"))
  | Some(config) => config
  }

  if p.createContainers {
    let referencedNames = StgBridge.extractContainerNames(config.stgGroups)
    let existingContainers = await ContainerManager.listContainers()
    let existingNames = existingContainers->Array.map(c => c.name)->Set.fromArray

    for idx in 0 to referencedNames->Array.length - 1 {
      let name = referencedNames->Array.getUnsafe(idx)
      if !(existingNames->Set.has(name)) {
        let _ = await ContainerManager.createContainer(
          ~name,
          ~color=(Constants.defaultColor :> string),
          ~icon=(Constants.defaultIcon :> string),
        )
      }
    }
    await NameResolver.refresh()
  }

  {ok: true}
})

MessageRouter.handleUnit(Constants.action["generateStgBackup"], async () => {
  let lastConfig = await StorageManager.getLastConfig()
  switch lastConfig->Nullable.toOption {
  | None =>
    throw(Errors.make(ConfigInvalid, "No config loaded — import or export a config first"))
  | Some(config) =>
    await StgBridge.downloadBackup(config)
    {ok: true}
  }
})

MessageRouter.setupMessageListener()

Browser.Runtime.OnInstalled.addListener(details => {
  StorageManager.migrate()
  ->Promise.catch(err => {
    Console.error2("[main] Storage migration failed:", err)
    Promise.resolve()
  })
  ->ignore

  if details.reason == "install" {
    ()
  }
})

NameResolver.initialize()
->Promise.catch(err => {
  Console.error2("[main] Name resolver init failed:", err)
  Promise.resolve()
})
->ignore

Console.log(`Container Toolbox v${Constants.extensionVersion} background loaded`)
