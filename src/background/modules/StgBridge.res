@@warning("-4")

let minStgVersion = "5.3"
let defaultStgVersion = "5.3"

// Compare "major.minor" version strings
let parseVersion = (s: string): (int, int) => {
  let parts = s->String.split(".")
  let major = parts->Array.get(0)->Option.flatMap(v => Int.fromString(v))->Option.getOr(0)
  let minor = parts->Array.get(1)->Option.flatMap(v => Int.fromString(v))->Option.getOr(0)
  (major, minor)
}

let isVersionSupported = (version: string): bool => {
  let (major, minor) = parseVersion(version)
  let (minMajor, minMinor) = parseVersion(minStgVersion)
  major > minMajor || (major == minMajor && minor >= minMinor)
}

// JSON field helpers — used throughout for parsing STG backup
let getString = (obj: Dict.t<JSON.t>, key: string, default: string): string =>
  obj->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.getOr(default)

let getBool = (obj: Dict.t<JSON.t>, key: string): bool =>
  obj->Dict.get(key)->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)

let getStringArray = (obj: Dict.t<JSON.t>, key: string): array<string> =>
  switch obj->Dict.get(key)->Option.flatMap(JSON.Decode.array) {
  | Some(arr) => arr->Array.filterMap(JSON.Decode.string)
  | None => []
  }

// Container ID <-> portable name substitution

// Resolve container ID to portable name using backup's own container map first
let idToPortableName = (id: string, ~backupContainers: Dict.t<string>=Dict.make()): string => {
  switch Constants.specialContainersReverse->Dict.get(id) {
  | Some(name) => name
  | None =>
    switch backupContainers->Dict.get(id) {
    | Some(name) => name
    | None =>
      try {NameResolver.resolveIdToName(id)} catch {
      | _ => id
      }
    }
  }
}

let portableNameToId = (name: string): string => {
  switch Constants.specialContainers->Dict.get(name) {
  | Some(id) => id
  | None =>
    try {NameResolver.resolveNameToId(name)} catch {
    | _ => name
    }
  }
}

let replaceContainerRef = (obj: Dict.t<JSON.t>, key: string, replacer: string => string) => {
  switch obj->Dict.get(key)->Option.flatMap(JSON.Decode.string) {
  | Some(id) => obj->Dict.set(key, JSON.String(replacer(id)))
  | None => ()
  }
}

let replaceContainerArrayRef = (obj: Dict.t<JSON.t>, key: string, replacer: string => string) => {
  switch obj->Dict.get(key)->Option.flatMap(JSON.Decode.array) {
  | Some(arr) =>
    obj->Dict.set(
      key,
      JSON.Array(
        arr->Array.map(v =>
          switch v->JSON.Decode.string {
          | Some(id) => JSON.String(replacer(id))
          | None => v
          }
        ),
      ),
    )
  | None => ()
  }
}

let parseGroup = (fields: Dict.t<JSON.t>): Types.stgGroupConfig => {
  title: getString(fields, "title", "Untitled"),
  iconColor: getString(fields, "iconColor", ""),
  iconViewType: getString(fields, "iconViewType", "circle"),
  newTabContainer: getString(fields, "newTabContainer", "$default"),
  catchTabContainers: getStringArray(fields, "catchTabContainers"),
  excludeContainersForReOpen: getStringArray(fields, "excludeContainersForReOpen"),
  isArchive: getBool(fields, "isArchive"),
  isSticky: getBool(fields, "isSticky"),
  discardTabsAfterHide: getBool(fields, "discardTabsAfterHide"),
  discardExcludeAudioTabs: getBool(fields, "discardExcludeAudioTabs"),
  muteTabsWhenGroupCloseAndRestoreWhenOpen: getBool(
    fields,
    "muteTabsWhenGroupCloseAndRestoreWhenOpen",
  ),
  prependTitleToWindow: getBool(fields, "prependTitleToWindow"),
  exportToBookmarksWhenAutoBackup: getBool(fields, "exportToBookmarksWhenAutoBackup"),
  leaveBookmarksOfClosedTabs: getBool(fields, "leaveBookmarksOfClosedTabs"),
  ifDifferentContainerReOpen: getBool(fields, "ifDifferentContainerReOpen"),
  showTabAfterMovingItIntoThisGroup: getBool(fields, "showTabAfterMovingItIntoThisGroup"),
  showOnlyActiveTabAfterMovingItIntoThisGroup: getBool(
    fields,
    "showOnlyActiveTabAfterMovingItIntoThisGroup",
  ),
  showNotificationAfterMovingTabIntoThisGroup: getBool(
    fields,
    "showNotificationAfterMovingTabIntoThisGroup",
  ),
  catchTabRules: getString(fields, "catchTabRules", ""),
  moveToGroupIfNoneCatchTabRules: switch fields
  ->Dict.get("moveToGroupIfNoneCatchTabRules")
  ->Option.flatMap(JSON.Decode.float) {
  | Some(n) => Nullable.make(n->Float.toInt)
  | None => Nullable.null
  },
  tabs: switch fields->Dict.get("tabs")->Option.flatMap(JSON.Decode.array) {
  | Some(arr) => arr
  | None => []
  },
}

type orphanedTab = {"group": string, "tab": string, "container": string}

type parseResult = {
  config: Types.containerToolboxConfig,
  orphanedTabs: array<orphanedTab>,
}

// Parse STG backup: validate version, replace IDs with portable names
let parseBackup = (backup: JSON.t): option<parseResult> => {
  switch backup->JSON.Decode.object {
  | None => None
  | Some(obj) =>
    let stgVer = obj->Dict.get("version")->Option.flatMap(JSON.Decode.string)
    switch stgVer {
    | Some(v) if !isVersionSupported(v) =>
      throw(
        Errors.make(
          StgBackupParseFailed,
          `STG version ${v} is not supported. Minimum required: ${minStgVersion}`,
        ),
      )
    | _ => ()
    }

    // Build ID→name map from the backup's own containers dict
    let backupContainers: Dict.t<string> = Dict.make()
    switch obj->Dict.get("containers")->Option.flatMap(JSON.Decode.object) {
    | Some(cDict) =>
      cDict->Dict.forEachWithKey((value, key) => {
        switch value->JSON.Decode.object {
        | Some(info) =>
          switch info->Dict.get("name")->Option.flatMap(JSON.Decode.string) {
          | Some(name) => backupContainers->Dict.set(key, name)
          | None => ()
          }
        | None => ()
        }
      })
    | None => ()
    }

    let toName = id => idToPortableName(id, ~backupContainers)

    // Track all known container IDs (backup dict + special)
    let knownIds = Set.make()
    backupContainers->Dict.keysToArray->Array.forEach(k => knownIds->Set.add(k))
    Constants.specialContainers->Dict.forEachWithKey((v, _k) => knownIds->Set.add(v))

    let groupsRaw = switch obj->Dict.get("groups")->Option.flatMap(JSON.Decode.array) {
    | Some(arr) => arr
    | None => []
    }

    let orphanedTabs: array<{"group": string, "tab": string, "container": string}> = []

    let groups = groupsRaw->Array.filterMap(g => {
      switch g->JSON.Decode.object {
      | Some(fields) =>
        let groupTitle = getString(fields, "title", "Untitled")
        // Replace container IDs with portable names using backup's map
        replaceContainerRef(fields, "newTabContainer", toName)
        replaceContainerArrayRef(fields, "catchTabContainers", toName)
        replaceContainerArrayRef(fields, "excludeContainersForReOpen", toName)

        // Get the group's newTabContainer (already converted to name)
        let groupContainer =
          fields
          ->Dict.get("newTabContainer")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("$default")

        // Replace cookieStoreId in each tab, auto-fix orphaned refs
        switch fields->Dict.get("tabs")->Option.flatMap(JSON.Decode.array) {
        | Some(tabs) =>
          fields->Dict.set(
            "tabs",
            JSON.Array(
              tabs->Array.map(tab => {
                switch tab->JSON.Decode.object {
                | Some(tabObj) =>
                  let currentId =
                    tabObj
                    ->Dict.get("cookieStoreId")
                    ->Option.flatMap(JSON.Decode.string)
                    ->Option.getOr("")

                  if currentId != "" && !(knownIds->Set.has(currentId)) {
                    // Orphaned: ID not in backup's containers dict
                    let tabTitle =
                      tabObj
                      ->Dict.get("title")
                      ->Option.flatMap(JSON.Decode.string)
                      ->Option.getOr("Untitled")
                    orphanedTabs
                    ->Array.push({
                      "group": groupTitle,
                      "tab": tabTitle,
                      "container": currentId,
                    })
                    ->ignore
                    // Auto-fix: reassign to group's newTabContainer
                    tabObj->Dict.set("cookieStoreId", JSON.String(groupContainer))
                  } else {
                    replaceContainerRef(tabObj, "cookieStoreId", toName)
                  }
                  JSON.Object(tabObj)
                | None => tab
                }
              }),
            ),
          )
        | None => ()
        }
        // Strip runtime fields (keep tabs for round-trip)
        fields->Dict.delete("id")
        fields->Dict.delete("bookmarkId")
        fields->Dict.delete("iconUrl")
        Some(parseGroup(fields))
      | None => None
      }
    })

    // Resolve hotkey groupId -> groupTitle
    let hotkeys = switch obj->Dict.get("hotkeys")->Option.flatMap(JSON.Decode.array) {
    | Some(arr) =>
      arr->Array.filterMap(h => {
        switch h->JSON.Decode.object {
        | Some(hObj) =>
          let groupId =
            hObj
            ->Dict.get("groupId")
            ->Option.flatMap(JSON.Decode.float)
            ->Option.map(Float.toInt)

          let groupTitle = switch groupId {
          | Some(id) if id > 0 =>
            groupsRaw
            ->Array.find(g =>
              g
              ->JSON.Decode.object
              ->Option.flatMap(gObj => gObj->Dict.get("id")->Option.flatMap(JSON.Decode.float))
              ->Option.map(gid => gid->Float.toInt == id)
              ->Option.getOr(false)
            )
            ->Option.flatMap(g =>
              g
              ->JSON.Decode.object
              ->Option.flatMap(gObj => gObj->Dict.get("title")->Option.flatMap(JSON.Decode.string))
            )
          | _ => None
          }

          Some({
            Types.value: getString(hObj, "value", ""),
            action: getString(hObj, "action", ""),
            ?groupTitle,
          })
        | None => None
        }
      })
    | None => []
    }

    let defaultGroupProps = switch obj
    ->Dict.get("defaultGroupProps")
    ->Option.flatMap(JSON.Decode.object) {
    | Some(dp) => {
        Types.prependTitleToWindow: getBool(dp, "prependTitleToWindow"),
        showNotificationAfterMovingTabIntoThisGroup: getBool(
          dp,
          "showNotificationAfterMovingTabIntoThisGroup",
        ),
      }
    | None => {
        prependTitleToWindow: false,
        showNotificationAfterMovingTabIntoThisGroup: false,
      }
    }

    let stgVersion = obj->Dict.get("version")->Option.flatMap(JSON.Decode.string)

    Some({
      config: {
        Types.version: 1,
        meta: {
          exportedAt: Date.make()->Date.toISOString,
          exportedFrom: `container-toolbox@${Constants.extensionVersion}`,
        },
        containers: [],
        stgGroups: groups,
        stgHotkeys: hotkeys,
        stgDefaultGroupProps: defaultGroupProps,
        ?stgVersion,
      },
      orphanedTabs,
    })
  }
}

// Generate STG-compatible backup: resolve names to local IDs
let generateBackup = (config: Types.containerToolboxConfig): JSON.t => {
  let groups = config.stgGroups->Array.mapWithIndex((group, i) => {
    JSON.Object(
      Dict.fromArray([
        ("id", JSON.Number((i + 1)->Int.toFloat)),
        ("title", JSON.String(group.title)),
        ("iconColor", JSON.String(group.iconColor)),
        ("iconUrl", JSON.Null),
        ("iconViewType", JSON.String(group.iconViewType)),
        (
          "tabs",
          JSON.Array(
            group.tabs->Array.map(tab => {
              switch tab->JSON.Decode.object {
              | Some(tabObj) =>
                let resolved = Dict.fromArray(tabObj->Dict.toArray)
                replaceContainerRef(resolved, "cookieStoreId", portableNameToId)
                JSON.Object(resolved)
              | None => tab
              }
            }),
          ),
        ),
        ("isArchive", JSON.Boolean(group.isArchive)),
        ("discardTabsAfterHide", JSON.Boolean(group.discardTabsAfterHide)),
        ("discardExcludeAudioTabs", JSON.Boolean(group.discardExcludeAudioTabs)),
        (
          "muteTabsWhenGroupCloseAndRestoreWhenOpen",
          JSON.Boolean(group.muteTabsWhenGroupCloseAndRestoreWhenOpen),
        ),
        ("prependTitleToWindow", JSON.Boolean(group.prependTitleToWindow)),
        ("exportToBookmarksWhenAutoBackup", JSON.Boolean(group.exportToBookmarksWhenAutoBackup)),
        ("leaveBookmarksOfClosedTabs", JSON.Boolean(group.leaveBookmarksOfClosedTabs)),
        ("newTabContainer", JSON.String(portableNameToId(group.newTabContainer))),
        ("ifDifferentContainerReOpen", JSON.Boolean(group.ifDifferentContainerReOpen)),
        (
          "excludeContainersForReOpen",
          JSON.Array(
            group.excludeContainersForReOpen->Array.map(n => JSON.String(portableNameToId(n))),
          ),
        ),
        ("isSticky", JSON.Boolean(group.isSticky)),
        (
          "showTabAfterMovingItIntoThisGroup",
          JSON.Boolean(group.showTabAfterMovingItIntoThisGroup),
        ),
        (
          "showOnlyActiveTabAfterMovingItIntoThisGroup",
          JSON.Boolean(group.showOnlyActiveTabAfterMovingItIntoThisGroup),
        ),
        (
          "showNotificationAfterMovingTabIntoThisGroup",
          JSON.Boolean(group.showNotificationAfterMovingTabIntoThisGroup),
        ),
        (
          "catchTabContainers",
          JSON.Array(group.catchTabContainers->Array.map(n => JSON.String(portableNameToId(n)))),
        ),
        ("catchTabRules", JSON.String(group.catchTabRules)),
        (
          "moveToGroupIfNoneCatchTabRules",
          switch group.moveToGroupIfNoneCatchTabRules->Nullable.toOption {
          | Some(n) => JSON.Number(n->Int.toFloat)
          | None => JSON.Null
          },
        ),
        ("bookmarkId", JSON.Null),
      ]),
    )
  })

  let hotkeys = config.stgHotkeys->Array.map(hk => {
    let groupId = switch hk.groupTitle {
    | Some(title) =>
      config.stgGroups
      ->Array.findIndexOpt(g => g.title == title)
      ->Option.map(idx => idx + 1)
      ->Option.getOr(0)
    | None => 0
    }
    JSON.Object(
      Dict.fromArray([
        ("value", JSON.String(hk.value)),
        ("action", JSON.String(hk.action)),
        ("groupId", JSON.Number(groupId->Int.toFloat)),
      ]),
    )
  })

  // Build containers dict: cookieStoreId -> {name, color, icon, iconUrl, colorCode}
  let containers: Dict.t<JSON.t> = Dict.make()
  config.stgGroups->Array.forEach(group => {
    let addContainer = (name: string) => {
      if !(Constants.specialContainers->Dict.get(name)->Option.isSome) {
        let id = portableNameToId(name)
        if !(containers->Dict.get(id)->Option.isSome) {
          try {
            let resolved = NameResolver.resolveNameToId(name)
            ignore(resolved)
            containers->Dict.set(
              id,
              JSON.Object(
                Dict.fromArray([
                  ("name", JSON.String(name)),
                  ("color", JSON.String("blue")),
                  ("icon", JSON.String("fingerprint")),
                  ("iconUrl", JSON.String("")),
                  ("colorCode", JSON.String("")),
                ]),
              ),
            )
          } catch {
          | _ => ()
          }
        }
      }
    }
    addContainer(group.newTabContainer)
    group.catchTabContainers->Array.forEach(addContainer)
    group.excludeContainersForReOpen->Array.forEach(addContainer)
  })

  JSON.Object(
    Dict.fromArray([
      ("version", JSON.String(config.stgVersion->Option.getOr(defaultStgVersion))),
      ("groups", JSON.Array(groups)),
      ("lastCreatedGroupPosition", JSON.Number(config.stgGroups->Array.length->Int.toFloat)),
      (
        "defaultGroupProps",
        JSON.Object(
          Dict.fromArray([
            (
              "prependTitleToWindow",
              JSON.Boolean(config.stgDefaultGroupProps.prependTitleToWindow),
            ),
            (
              "showNotificationAfterMovingTabIntoThisGroup",
              JSON.Boolean(config.stgDefaultGroupProps.showNotificationAfterMovingTabIntoThisGroup),
            ),
          ]),
        ),
      ),
      ("hotkeys", JSON.Array(hotkeys)),
      ("containers", JSON.Object(containers)),
      ("pinnedTabs", JSON.Array([])),
    ]),
  )
}

// Extract all container names referenced by STG groups (excluding special containers)
let extractContainerNames = (groups: array<Types.stgGroupConfig>): array<string> => {
  let names = Set.make()
  groups->Array.forEach(g => {
    let ntc = g.newTabContainer
    if ntc != "" && !(Constants.specialContainers->Dict.get(ntc)->Option.isSome) {
      names->Set.add(ntc)
    }
    g.catchTabContainers->Array.forEach(c => {
      if !(Constants.specialContainers->Dict.get(c)->Option.isSome) {
        names->Set.add(c)
      }
    })
    g.excludeContainersForReOpen->Array.forEach(c => {
      if !(Constants.specialContainers->Dict.get(c)->Option.isSome) {
        names->Set.add(c)
      }
    })
  })
  names->Set.values->Iterator.toArray
}

type containerInfo = {
  name: string,
  color: string,
  icon: string,
}

// Extract container details from STG backup's containers dict
let extractBackupContainers = (backup: JSON.t): array<containerInfo> => {
  switch backup->JSON.Decode.object {
  | None => []
  | Some(obj) =>
    switch obj->Dict.get("containers")->Option.flatMap(JSON.Decode.object) {
    | None => []
    | Some(cDict) =>
      let result: array<containerInfo> = []
      cDict->Dict.forEachWithKey((value, _key) => {
        switch value->JSON.Decode.object {
        | Some(info) =>
          let name = info->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
          if name != "" {
            result
            ->Array.push({
              name,
              color: info
              ->Dict.get("color")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr("blue"),
              icon: info
              ->Dict.get("icon")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr("fingerprint"),
            })
            ->ignore
          }
        | None => ()
        }
      })
      result
    }
  }
}

let createBlobUrl: string => string = %raw(`
  function(json) {
    var blob = new Blob([json], { type: "application/json" });
    return URL.createObjectURL(blob);
  }
`)

let downloadBackup = async (config: Types.containerToolboxConfig) => {
  let backup = generateBackup(config)
  let json = JSON.stringify(backup)
  let blobUrl = createBlobUrl(json)

  let _ = await Browser.Downloads.download({
    "url": blobUrl,
    "filename": `stg-backup-${Date.make()->Date.toISOString->String.slice(~start=0, ~end=10)}.json`,
    "saveAs": true,
  })
}
