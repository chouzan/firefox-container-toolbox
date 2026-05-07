@genType
type errorCode =
  // Container
  | @as("CONTAINER_NOT_FOUND") ContainerNotFound
  | @as("CONTAINER_DUPLICATE_NAME") ContainerDuplicateName
  | @as("CONTAINER_CREATE_FAILED") ContainerCreateFailed
  // Name resolution
  | @as("NAME_NOT_RESOLVED") NameNotResolved
  | @as("ID_NOT_RESOLVED") IdNotResolved
  // STG
  | @as("STG_NOT_INSTALLED") StgNotInstalled
  | @as("STG_COMMUNICATION_FAILED") StgCommunicationFailed
  | @as("STG_BACKUP_PARSE_FAILED") StgBackupParseFailed
  // Drive
  | @as("DRIVE_NOT_AUTHENTICATED") DriveNotAuthenticated
  | @as("DRIVE_TOKEN_EXPIRED") DriveTokenExpired
  | @as("DRIVE_FILE_NOT_FOUND") DriveFileNotFound
  | @as("DRIVE_NETWORK_ERROR") DriveNetworkError
  // Config
  | @as("CONFIG_INVALID") ConfigInvalid
  | @as("CONFIG_SCHEMA_MISMATCH") ConfigSchemaMismatch
  // Sync
  | @as("SYNC_CONFLICT") SyncConflict
  | @as("SYNC_IN_PROGRESS") SyncInProgress
  // Internal
  | @as("INTERNAL_ERROR") InternalError

@genType
type errorInfo = {
  code: errorCode,
  message: string,
}

exception AppError(errorInfo)

let make = (code: errorCode, message: string) => {
  AppError({code, message})
}

let toInfo = (err: exn): errorInfo => {
  switch err {
  | AppError(info) => info
  | JsExn(jsErr) =>
    let msg = jsErr->JsExn.message->Option.getOr("Unknown JS error")
    {code: InternalError, message: msg}
  | _ => {code: InternalError, message: "Unknown error"}
  }
}
