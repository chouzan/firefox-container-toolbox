let nameToId: Dict.t<string> = Dict.make()
let idToName: Dict.t<string> = Dict.make()
let debounceTimer: ref<option<timeoutId>> = ref(None)
let initialized = ref(false)

let buildSpecialMappings = () => {
  Constants.specialContainers->Dict.forEachWithKey((value, key) => {
    nameToId->Dict.set(key, value)
    idToName->Dict.set(value, key)
  })
}

let clearMaps = () => {
  nameToId
  ->Dict.keysToArray
  ->Array.forEach(k => {
    nameToId->Dict.delete(k)
  })
  idToName
  ->Dict.keysToArray
  ->Array.forEach(k => {
    idToName->Dict.delete(k)
  })
}

let rebuildFromLive = async () => {
  let containers = await Browser.ContextualIdentities.queryAll()
  clearMaps()
  buildSpecialMappings()

  let seen: Dict.t<string> = Dict.make()
  containers->Array.forEach(c => {
    switch seen->Dict.get(c.name) {
    | Some(existing) =>
      Console.warn3(
        "[name-resolver] Duplicate container name:",
        c.name,
        `keeping ${existing}, ignoring ${c.cookieStoreId}`,
      )
    | None =>
      seen->Dict.set(c.name, c.cookieStoreId)
      nameToId->Dict.set(c.name, c.cookieStoreId)
      idToName->Dict.set(c.cookieStoreId, c.name)
    }
  })

  let cache: Types.nameCache = {
    nameToId: nameToId->Dict.copy,
    idToName: idToName->Dict.copy,
    updatedAt: Nullable.make(Date.make()->Date.toISOString),
  }
  await StorageManager.setNameCache(cache)
}

let debouncedRebuild = () => {
  switch debounceTimer.contents {
  | Some(timer) => clearTimeout(timer)
  | None => ()
  }
  debounceTimer := Some(setTimeout(() => {
        debounceTimer := None
        rebuildFromLive()
        ->Promise.catch(err => {
          Console.error2("[name-resolver] Rebuild failed:", err)
          Promise.resolve()
        })
        ->ignore
      }, 100))
}

let onContainerChanged = (_: Browser.ContextualIdentities.changeInfo) => {
  debouncedRebuild()
}

let initialize = async () => {
  if initialized.contents {
    ()
  } else {
    await rebuildFromLive()
    Browser.ContextualIdentities.OnCreated.addListener(onContainerChanged)
    Browser.ContextualIdentities.OnRemoved.addListener(onContainerChanged)
    Browser.ContextualIdentities.OnUpdated.addListener(onContainerChanged)
    initialized := true
  }
}

let resolveNameToId = (name: string): string => {
  switch Constants.specialContainers->Dict.get(name) {
  | Some(id) => id
  | None =>
    switch nameToId->Dict.get(name) {
    | Some(id) => id
    | None => throw(Errors.make(NameNotResolved, `Container name "${name}" not found`))
    }
  }
}

let resolveIdToName = (id: string): string => {
  switch Constants.specialContainersReverse->Dict.get(id) {
  | Some(name) => name
  | None =>
    switch idToName->Dict.get(id) {
    | Some(name) => name
    | None => throw(Errors.make(IdNotResolved, `Container ID "${id}" not found`))
    }
  }
}

let resolveNamesToIds = (names: array<string>): array<string> => {
  names->Array.map(resolveNameToId)
}

let resolveIdsToNames = (ids: array<string>): array<string> => {
  ids->Array.map(resolveIdToName)
}

let isSpecialId = (id: string): bool => {
  Constants.specialContainersReverse->Dict.get(id)->Option.isSome
}

let isSpecialName = (name: string): bool => {
  Constants.specialContainers->Dict.get(name)->Option.isSome
}

let getNameToId = (): Dict.t<string> => nameToId->Dict.copy

let getIdToName = (): Dict.t<string> => idToName->Dict.copy

let refresh = async () => {
  await rebuildFromLive()
}

let suppressEvents = () => {
  switch debounceTimer.contents {
  | Some(timer) =>
    clearTimeout(timer)
    debounceTimer := None
  | None => ()
  }
}
