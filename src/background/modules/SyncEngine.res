let pullAndApply = async (): Types.reconcileResult => {
  let remoteConfig = await DriveClient.pullConfig()

  switch remoteConfig->Nullable.toOption {
  | None => throw(Errors.make(DriveFileNotFound, "No config found on Drive"))
  | Some(config) =>
    if !Validators.validateConfig(Obj.magic(config)) {
      throw(Errors.make(ConfigInvalid, "Remote config is invalid"))
    }

    await StorageManager.setLastConfig(Nullable.make(config))

    let result = await ContainerManager.reconcile(config.containers)

    let syncState = await StorageManager.getSyncState()
    let _ = await StorageManager.updateSyncState({
      ...syncState,
      lastPullAt: Nullable.make(Date.make()->Date.toISOString),
    })

    result
  }
}

let exportAndPush = async () => {
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

  await DriveClient.pushConfig(config)
  await StorageManager.setLastConfig(Nullable.make(config))

  let syncState = await StorageManager.getSyncState()
  let _ = await StorageManager.updateSyncState({
    ...syncState,
    lastPushAt: Nullable.make(Date.make()->Date.toISOString),
  })

  config
}

let forcePushLocal = async () => {
  await exportAndPush()
}

let clearRemote = async () => {
  await DriveClient.deleteConfig()

  let syncState = await StorageManager.getSyncState()
  let _ = await StorageManager.updateSyncState({
    ...syncState,
    lastPushAt: Nullable.null,
    lastPullAt: Nullable.null,
  })
}
