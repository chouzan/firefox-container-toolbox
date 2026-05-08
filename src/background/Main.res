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

MessageRouter.handle(Constants.action["importConfig"], async (payload: JSON.t) => {
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
