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

// Storage trust boundary — we wrote the data, so we know the shape.
// Obj.magic is used here to cast untyped JSON from browser.storage.local
// to the expected ReScript types. This is the ONLY place it's needed.
let getSection = async (key: string, default: 'a): 'a => {
  let result = await Browser.Storage.getAll()
  let dict: Dict.t<JSON.t> = Obj.magic(result)
  switch dict->Dict.get(key) {
  | Some(v) if v !== JSON.Null => Obj.magic(v)
  | _ => default
  }
}

let setSection = async (key: string, value: 'a): unit => {
  let obj: Dict.t<JSON.t> = Dict.make()
  obj->Dict.set(key, Obj.magic(value))
  await Browser.Storage.set(Obj.magic(obj))
}

// Object.assign({}, base, partial) — shallow merge
let merge: ('a, 'a) => 'a = %raw(`
  function(a, b) { return Object.assign({}, a, b); }
`)

let mergePartial: ('a, JSON.t) => 'a = %raw(`
  function(a, b) { return Object.assign({}, a, b); }
`)

let getSettings = async (): settings => {
  await getSection("settings", defaultSettings)
}

let updateSettings = async (partial: settings): settings => {
  let current = await getSettings()
  let merged = merge(current, partial)
  await setSection("settings", merged)
  merged
}

let updatePartialSettings = async (partial: JSON.t): settings => {
  let current = await getSettings()
  let merged = mergePartial(current, partial)
  await setSection("settings", merged)
  merged
}

let getDriveAuth = async (): driveAuth => {
  let section: option<authSection> = await getSection("auth", None)
  switch section {
  | Some(auth) => auth.drive
  | None => defaultDriveAuth
  }
}

let setDriveAuth = async (auth: driveAuth): unit => {
  await setSection("auth", {drive: auth})
}

let getNameCache = async (): nameCache => {
  await getSection("nameCache", defaultNameCache)
}

let setNameCache = async (cache: nameCache): unit => {
  await setSection("nameCache", cache)
}

let getSyncState = async (): syncState => {
  await getSection("syncState", defaultSyncState)
}

let updateSyncState = async (partial: syncState): syncState => {
  let current = await getSyncState()
  let merged = merge(current, partial)
  await setSection("syncState", merged)
  merged
}

let getLastConfig = async (): Nullable.t<containerToolboxConfig> => {
  let result: option<containerToolboxConfig> = await getSection("lastConfig", None)
  switch result {
  | Some(config) => Nullable.make(config)
  | None => Nullable.null
  }
}

let setLastConfig = async (config: Nullable.t<containerToolboxConfig>): unit => {
  await setSection("lastConfig", config)
}

let migrate = async (): unit => {
  let version: int = await getSection("_schemaVersion", 0)

  if version == 0 {
    await setSection("_schemaVersion", Constants.currentSchemaVersion)
    await setSection("settings", defaultSettings)
    await setSection("auth", {drive: defaultDriveAuth})
    await setSection("nameCache", defaultNameCache)
    await setSection("syncState", defaultSyncState)
    await setSection("lastConfig", Nullable.null)
  } else if version < Constants.currentSchemaVersion {
    await setSection("_schemaVersion", Constants.currentSchemaVersion)
  }
}
