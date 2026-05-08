open Types

let defaultSettings: settings = {
  stgStrategy: FileBridge,
  conflictResolution: LocalWins,
  syncEnabled: false,
  driveFileId: Nullable.null,
  driveFolderId: Nullable.null,
  driveFileName: Constants.defaultDriveFilename,
  notifications: {
    syncSuccess: true,
    syncFailure: true,
    conflictsDetected: true,
  },
}

let defaultDriveAuth: driveAuth = {
  accessToken: Nullable.null,
  refreshToken: Nullable.null,
  expiresAt: Nullable.null,
  clientId: Nullable.null,
  clientSecret: Nullable.null,
}

let defaultNameCache: nameCache = {
  nameToId: Dict.make(),
  idToName: Dict.make(),
  updatedAt: Nullable.null,
}

let defaultSyncState: syncState = {
  lastPullAt: Nullable.null,
  lastPushAt: Nullable.null,
  lastReconcileAt: Nullable.null,
  lastConfigHash: Nullable.null,
  pendingConflicts: [],
}

// Object.assign({}, base, partial) — shallow merge, untypable empty literal
let merge: ('a, 'a) => 'a = %raw(`
  function(a, b) { return Object.assign({}, a, b); }
`)

let mergePartial: ('a, JSON.t) => 'a = %raw(`
  function(a, b) { return Object.assign({}, a, b); }
`)

let getSettings = async (): settings => {
  let result = await Browser.Storage.get({"settings": Nullable.null})
  let r: {"settings": Nullable.t<settings>} = result
  r["settings"]->Nullable.toOption->Option.getOr(defaultSettings)
}

let updateSettings = async (partial: settings): settings => {
  let current = await getSettings()
  let merged = merge(current, partial)
  await Browser.Storage.set({"settings": merged})
  merged
}

let updatePartialSettings = async (partial: JSON.t): settings => {
  let current = await getSettings()
  let merged = mergePartial(current, partial)
  await Browser.Storage.set({"settings": merged})
  merged
}

let getDriveAuth = async (): driveAuth => {
  let result = await Browser.Storage.get({"auth": Nullable.null})
  let r: {"auth": Nullable.t<{"drive": driveAuth}>} = result
  switch r["auth"]->Nullable.toOption {
  | Some(a) => a["drive"]
  | None => defaultDriveAuth
  }
}

let setDriveAuth = async (auth: driveAuth): unit => {
  await Browser.Storage.set({"auth": {"drive": auth}})
}

let getNameCache = async (): nameCache => {
  let result = await Browser.Storage.get({"nameCache": Nullable.null})
  let r: {"nameCache": Nullable.t<nameCache>} = result
  r["nameCache"]->Nullable.toOption->Option.getOr(defaultNameCache)
}

let setNameCache = async (cache: nameCache): unit => {
  await Browser.Storage.set({"nameCache": cache})
}

let getSyncState = async (): syncState => {
  let result = await Browser.Storage.get({"syncState": Nullable.null})
  let r: {"syncState": Nullable.t<syncState>} = result
  r["syncState"]->Nullable.toOption->Option.getOr(defaultSyncState)
}

let updateSyncState = async (partial: syncState): syncState => {
  let current = await getSyncState()
  let merged = merge(current, partial)
  await Browser.Storage.set({"syncState": merged})
  merged
}

let getLastConfig = async (): Nullable.t<containerToolboxConfig> => {
  let result = await Browser.Storage.get({"lastConfig": Nullable.null})
  let r: {"lastConfig": Nullable.t<containerToolboxConfig>} = result
  r["lastConfig"]
}

let setLastConfig = async (config: Nullable.t<containerToolboxConfig>): unit => {
  await Browser.Storage.set({"lastConfig": config})
}

let migrate = async (): unit => {
  let result = await Browser.Storage.get({"_schemaVersion": Nullable.null})
  let r: {"_schemaVersion": Nullable.t<int>} = result
  let version = r["_schemaVersion"]->Nullable.toOption->Option.getOr(0)

  if version == 0 {
    await Browser.Storage.set({
      "_schemaVersion": Constants.currentSchemaVersion,
      "settings": defaultSettings,
      "auth": {"drive": defaultDriveAuth},
      "nameCache": defaultNameCache,
      "syncState": defaultSyncState,
      "lastConfig": Nullable.null,
    })
  } else if version < Constants.currentSchemaVersion {
    await Browser.Storage.set({"_schemaVersion": Constants.currentSchemaVersion})
  }
}
