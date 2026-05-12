open Constants

@genType
type containerConfig = {
  name: string,
  color: containerColor,
  icon: containerIcon,
  order: int,
}

@genType
type stgGroupConfig = {
  title: string,
  iconColor: string,
  iconViewType: string,
  newTabContainer: string,
  catchTabContainers: array<string>,
  excludeContainersForReOpen: array<string>,
  isArchive: bool,
  isSticky: bool,
  discardTabsAfterHide: bool,
  discardExcludeAudioTabs: bool,
  muteTabsWhenGroupCloseAndRestoreWhenOpen: bool,
  prependTitleToWindow: bool,
  exportToBookmarksWhenAutoBackup: bool,
  leaveBookmarksOfClosedTabs: bool,
  ifDifferentContainerReOpen: bool,
  showTabAfterMovingItIntoThisGroup: bool,
  showOnlyActiveTabAfterMovingItIntoThisGroup: bool,
  showNotificationAfterMovingTabIntoThisGroup: bool,
  catchTabRules: string,
  moveToGroupIfNoneCatchTabRules: Nullable.t<int>,
  tabs: array<JSON.t>,
}

@genType
type stgHotkeyConfig = {
  value: string,
  action: string,
  groupTitle?: string,
}

@genType
type stgDefaultGroupProps = {
  prependTitleToWindow: bool,
  showNotificationAfterMovingTabIntoThisGroup: bool,
}

@genType
type configMeta = {
  exportedAt: string,
  exportedFrom: string,
}

@genType
type containerToolboxConfig = {
  version: int,
  meta: configMeta,
  containers: array<containerConfig>,
  stgGroups: array<stgGroupConfig>,
  stgHotkeys: array<stgHotkeyConfig>,
  stgDefaultGroupProps: stgDefaultGroupProps,
  stgVersion?: string,
}

@genType
type notificationSettings = {
  syncSuccess: bool,
  syncFailure: bool,
  conflictsDetected: bool,
}

@genType
type stgStrategy =
  | @as("file-bridge") FileBridge
  | @as("messaging") Messaging

@genType
type settings = {
  stgStrategy: stgStrategy,
  conflictResolution: Constants.conflictResolution,
  syncEnabled: bool,
  driveFileId: Nullable.t<string>,
  driveFolderId: Nullable.t<string>,
  driveFileName: string,
  notifications: notificationSettings,
}

@genType
type driveAuth = {
  accessToken: Nullable.t<string>,
  refreshToken: Nullable.t<string>,
  expiresAt: Nullable.t<float>,
  clientId: Nullable.t<string>,
  clientSecret: Nullable.t<string>,
}

@genType
type nameCache = {
  nameToId: Dict.t<string>,
  idToName: Dict.t<string>,
  updatedAt: Nullable.t<string>,
}

@genType
type conflictValue = {
  name: string,
  color: string,
  icon: string,
}

@genType
type syncConflict = {
  id: string,
  @as("type") type_: string,
  description: string,
  localValue: Nullable.t<conflictValue>,
  remoteValue: Nullable.t<conflictValue>,
}

@genType
type syncState = {
  lastPullAt: Nullable.t<string>,
  lastPushAt: Nullable.t<string>,
  lastReconcileAt: Nullable.t<string>,
  lastConfigHash: Nullable.t<string>,
  pendingConflicts: array<syncConflict>,
}

@genType
type authSection = {drive: driveAuth}

@genType
type reconcileResult = {
  created: array<string>,
  updated: array<string>,
  removed: array<string>,
  reordered: bool,
  extras: array<string>,
}
