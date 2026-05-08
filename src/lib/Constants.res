@genType
let extensionId = "container-toolbox@chouzan"

@genType
let extensionVersion = "0.1.0"

@genType
let stgExtensionId = "simple-tab-groups@drive4ik"

// Firefox built-in container colour set
@genType
type containerColor =
  | @as("blue") Blue
  | @as("turquoise") Turquoise
  | @as("green") Green
  | @as("yellow") Yellow
  | @as("orange") Orange
  | @as("red") Red
  | @as("pink") Pink
  | @as("purple") Purple
  | @as("toolbar") Toolbar

@genType
let containerColors: array<containerColor> = [
  Blue,
  Turquoise,
  Green,
  Yellow,
  Orange,
  Red,
  Pink,
  Purple,
  Toolbar,
]

// Firefox built-in container icon set
@genType
type containerIcon =
  | @as("fingerprint") Fingerprint
  | @as("briefcase") Briefcase
  | @as("dollar") Dollar
  | @as("cart") Cart
  | @as("vacation") Vacation
  | @as("gift") Gift
  | @as("food") Food
  | @as("fruit") Fruit
  | @as("pet") Pet
  | @as("tree") Tree
  | @as("chill") Chill
  | @as("circle") Circle
  | @as("fence") Fence

@genType
let containerIcons: array<containerIcon> = [
  Fingerprint,
  Briefcase,
  Dollar,
  Cart,
  Vacation,
  Gift,
  Food,
  Fruit,
  Pet,
  Tree,
  Chill,
  Circle,
  Fence,
]

// Portable name <-> Firefox internal ID for special containers
@genType
let specialContainers = dict{
  "$default": "firefox-default",
  "$private": "firefox-private",
  "$temporary": "temporary-container",
}

@genType
let specialContainersReverse = dict{
  "firefox-default": "$default",
  "firefox-private": "$private",
  "temporary-container": "$temporary",
}

@genType
let defaultColor: containerColor = Blue

@genType
let defaultIcon: containerIcon = Fingerprint

@genType
type conflictResolution =
  | @as("config-wins") ConfigWins
  | @as("local-wins") LocalWins
  | @as("ask") Ask

@genType
let defaultConflictResolution: conflictResolution = LocalWins

@genType
let currentSchemaVersion = 1

@genType
let messagePrefix = "container-toolbox:"

@genType
let defaultDriveFilename = "container-toolbox-config.json"

@genType
let configVersion = 1

@genType
let action = {
  "getStatus": "GET_STATUS",
  "getContainers": "GET_CONTAINERS",
  "getSettings": "GET_SETTINGS",
  "updateSettings": "UPDATE_SETTINGS",
  "createContainer": "CREATE_CONTAINER",
  "updateContainer": "UPDATE_CONTAINER",
  "deleteContainer": "DELETE_CONTAINER",
  "moveContainer": "MOVE_CONTAINER",
  "reconcileNow": "RECONCILE_NOW",
  "exportConfig": "EXPORT_CONFIG",
  "importConfig": "IMPORT_CONFIG",
  "getConflicts": "GET_CONFLICTS",
  "resolveConflict": "RESOLVE_CONFLICT",
  "driveAuthenticate": "DRIVE_AUTHENTICATE",
  "driveRevoke": "DRIVE_REVOKE",
  "driveStatus": "DRIVE_STATUS",
  "driveSetCredentials": "DRIVE_SET_CREDENTIALS",
  "syncPull": "SYNC_PULL",
  "syncPush": "SYNC_PUSH",
  "forcePushLocal": "FORCE_PUSH_LOCAL",
  "clearRemote": "CLEAR_REMOTE",
}
