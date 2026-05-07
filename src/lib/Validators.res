@genType
let isValidColor = (color: string): bool => {
  Constants.containerColors->Array.some(c => (c :> string) == color)
}

@genType
let isValidIcon = (icon: string): bool => {
  Constants.containerIcons->Array.some(i => (i :> string) == icon)
}

// Validation uses raw JS for dynamic type checking on unknown data
@genType
let validateConfig: JSON.t => bool = %raw(`
  function validateConfig(data) {
    if (typeof data !== "object" || data === null) return false;
    var d = data;
    if (d.version !== 1) return false;

    // meta
    if (typeof d.meta !== "object" || d.meta === null) return false;
    if (typeof d.meta.exportedAt !== "string") return false;
    if (typeof d.meta.exportedFrom !== "string") return false;

    // containers
    if (!Array.isArray(d.containers)) return false;
    for (var i = 0; i < d.containers.length; i++) {
      var c = d.containers[i];
      if (typeof c !== "object" || c === null) return false;
      if (typeof c.name !== "string" || c.name.length === 0) return false;
      if (typeof c.color !== "string") return false;
      if (typeof c.icon !== "string") return false;
      if (typeof c.order !== "number" || !Number.isInteger(c.order) || c.order < 0) return false;
    }

    // stgGroups
    if (!Array.isArray(d.stgGroups)) return false;
    for (var j = 0; j < d.stgGroups.length; j++) {
      if (typeof d.stgGroups[j] !== "object" || d.stgGroups[j] === null) return false;
      if (typeof d.stgGroups[j].title !== "string") return false;
    }

    // stgHotkeys
    if (!Array.isArray(d.stgHotkeys)) return false;

    // stgDefaultGroupProps
    if (typeof d.stgDefaultGroupProps !== "object" || d.stgDefaultGroupProps === null) return false;

    return true;
  }
`)
