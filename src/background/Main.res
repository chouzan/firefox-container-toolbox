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

MessageRouter.handleUnit("GET_STATUS", async () => {
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

MessageRouter.handleUnit("GET_CONTAINERS", async () => {
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

MessageRouter.handleUnit("GET_SETTINGS", async () => {
  await StorageManager.getSettings()
})

MessageRouter.handle("UPDATE_SETTINGS", async (payload: JSON.t) => {
  await StorageManager.updatePartialSettings(payload)
})

MessageRouter.handle("CREATE_CONTAINER", async (p: createPayload) => {
  await ContainerManager.createContainer(~name=p.name, ~color=p.color, ~icon=p.icon)
})

MessageRouter.handle("UPDATE_CONTAINER", async (p: updatePayload) => {
  await ContainerManager.updateContainer(p.cookieStoreId, p.updates)
})

MessageRouter.handle("DELETE_CONTAINER", async (p: deletePayload) => {
  await ContainerManager.removeContainer(p.cookieStoreId)
  {ok: true}
})

MessageRouter.handle("MOVE_CONTAINER", async (p: movePayload) => {
  await Browser.ContextualIdentities.move(p.cookieStoreId, p.position)
  {ok: true}
})

MessageRouter.handleUnit("RECONCILE_NOW", async () => {
  let lastConfig = await StorageManager.getLastConfig()
  switch lastConfig->Nullable.toOption {
  | None => throw(Errors.make(ConfigInvalid, "No config loaded — import or pull a config first"))
  | Some(config) => await ContainerManager.reconcile(config.containers)
  }
})

MessageRouter.handleUnit("EXPORT_CONFIG", async () => {
  let containers = await ContainerManager.listContainers()
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
    stgGroups: [],
    stgHotkeys: [],
    stgDefaultGroupProps: {
      prependTitleToWindow: false,
      showNotificationAfterMovingTabIntoThisGroup: false,
    },
  }
  await StorageManager.setLastConfig(Nullable.make(config))
  config
})

MessageRouter.handle("IMPORT_CONFIG", async (payload: JSON.t) => {
  if !Validators.validateConfig(payload) {
    throw(Errors.make(ConfigInvalid, "Invalid config format"))
  }
  // Validated — safe to treat as typed
  let config: Types.containerToolboxConfig = Obj.magic(payload)
  await StorageManager.setLastConfig(Nullable.make(config))
  await ContainerManager.reconcile(config.containers)
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
