@genType let extensionId = "container-toolbox@chouzan"
@genType let extensionVersion = "0.1.0"
@genType let stgExtensionId = "simple-tab-groups@drive4ik"

// Firefox built-in container color set
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
  | @as("circle") Circle
  | @as("gift") Gift
  | @as("vacation") Vacation
  | @as("food") Food
  | @as("fruit") Fruit
  | @as("pet") Pet
  | @as("tree") Tree
  | @as("chill") Chill
  | @as("fence") Fence

@genType
let containerIcons: array<containerIcon> = [
  Fingerprint,
  Briefcase,
  Dollar,
  Cart,
  Circle,
  Gift,
  Vacation,
  Food,
  Fruit,
  Pet,
  Tree,
  Chill,
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

@genType let currentSchemaVersion = 1
@genType let messagePrefix = "container-toolbox:"
@genType let defaultDriveFilename = "container-toolbox-config.json"
@genType let configVersion = 1
