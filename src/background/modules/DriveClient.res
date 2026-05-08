let driveApiBase = "https://www.googleapis.com/drive/v3"
let driveUploadBase = "https://www.googleapis.com/upload/drive/v3"
let oauthTokenUrl = "https://oauth2.googleapis.com/token"
let oauthAuthUrl = "https://accounts.google.com/o/oauth2/v2/auth"
let driveScope = "https://www.googleapis.com/auth/drive.file"

let getAuth = async () => {
  let auth = await StorageManager.getDriveAuth()
  switch (auth.clientId->Nullable.toOption, auth.clientSecret->Nullable.toOption) {
  | (Some(clientId), Some(clientSecret)) => (auth, clientId, clientSecret)
  | _ => throw(Errors.make(DriveNotAuthenticated, "Drive client ID and secret are not configured"))
  }
}

let getValidToken = async () => {
  let (auth, clientId, clientSecret) = await getAuth()
  let now = Date.now()

  switch (auth.accessToken->Nullable.toOption, auth.expiresAt->Nullable.toOption) {
  | (Some(token), Some(expiresAt)) if now < expiresAt -. 60000.0 => token
  | _ =>
    switch auth.refreshToken->Nullable.toOption {
    | Some(refreshToken) =>
      let body =
        [
          ("grant_type", "refresh_token"),
          ("client_id", clientId),
          ("client_secret", clientSecret),
          ("refresh_token", refreshToken),
        ]
        ->Array.map(((k, v)) => `${k}=${Browser.encodeURIComponent(v)}`)
        ->Array.join("&")

      let response = await Browser.Fetch.fetch(
        oauthTokenUrl,
        {
          "method": "POST",
          "headers": {"Content-Type": "application/x-www-form-urlencoded"},
          "body": body,
        },
      )

      if !response.ok {
        throw(Errors.make(DriveTokenExpired, "Failed to refresh Drive token"))
      }

      let token: {
        "access_token": string,
        "expires_in": float,
      } = await response->Browser.Fetch.jsonAs

      await StorageManager.setDriveAuth({
        ...auth,
        accessToken: Nullable.make(token["access_token"]),
        expiresAt: Nullable.make(now +. token["expires_in"] *. 1000.0),
      })

      token["access_token"]
    | None =>
      throw(Errors.make(DriveNotAuthenticated, "No refresh token — please re-authenticate"))
    }
  }
}

let authenticate = async () => {
  let (auth, clientId, clientSecret) = await getAuth()
  let redirectUrl = Browser.Identity.getRedirectURL()

  let authUrl =
    oauthAuthUrl ++
    `?client_id=${Browser.encodeURIComponent(clientId)}` ++
    `&redirect_uri=${Browser.encodeURIComponent(redirectUrl)}` ++
    `&response_type=code` ++
    `&scope=${Browser.encodeURIComponent(driveScope)}` ++
    `&access_type=offline` ++ `&prompt=consent`

  let responseUrl = await Browser.Identity.launchWebAuthFlow({
    "url": authUrl,
    "interactive": true,
  })

  let urlObj = Browser.URL.make(responseUrl)
  let code = urlObj->Browser.URL.searchParams->Browser.URLSearchParams.get("code")

  switch code->Nullable.toOption {
  | None => throw(Errors.make(DriveNotAuthenticated, "No authorization code received"))
  | Some(code) =>
    let body =
      [
        ("grant_type", "authorization_code"),
        ("client_id", clientId),
        ("client_secret", clientSecret),
        ("redirect_uri", redirectUrl),
        ("code", code),
      ]
      ->Array.map(((k, v)) => `${k}=${Browser.encodeURIComponent(v)}`)
      ->Array.join("&")

    let response = await Browser.Fetch.fetch(
      oauthTokenUrl,
      {
        "method": "POST",
        "headers": {"Content-Type": "application/x-www-form-urlencoded"},
        "body": body,
      },
    )

    if !response.ok {
      throw(Errors.make(DriveNotAuthenticated, "Token exchange failed"))
    }

    let token: {
      "access_token": string,
      "refresh_token": option<string>,
      "expires_in": float,
    } = await response->Browser.Fetch.jsonAs

    let now = Date.now()
    await StorageManager.setDriveAuth({
      ...auth,
      accessToken: Nullable.make(token["access_token"]),
      refreshToken: switch token["refresh_token"] {
      | Some(rt) => Nullable.make(rt)
      | None => auth.refreshToken
      },
      expiresAt: Nullable.make(now +. token["expires_in"] *. 1000.0),
    })
  }
}

let revokeAuth = async () => {
  let auth = await StorageManager.getDriveAuth()
  switch auth.accessToken->Nullable.toOption {
  | Some(token) =>
    let _ = await Browser.Fetch.fetchUrl(
      `https://oauth2.googleapis.com/revoke?token=${Browser.encodeURIComponent(token)}`,
    )
  | None => ()
  }
  await StorageManager.setDriveAuth({
    accessToken: Nullable.null,
    refreshToken: Nullable.null,
    expiresAt: Nullable.null,
    clientId: auth.clientId,
    clientSecret: auth.clientSecret,
  })
}

let isAuthenticated = async () => {
  let auth = await StorageManager.getDriveAuth()
  auth.accessToken->Nullable.toOption->Option.isSome
}

let pullConfig = async (): Nullable.t<Types.containerToolboxConfig> => {
  let settings = await StorageManager.getSettings()
  switch settings.driveFileId->Nullable.toOption {
  | None => Nullable.null
  | Some(fileId) =>
    let token = await getValidToken()
    let response = await Browser.Fetch.fetch(
      `${driveApiBase}/files/${fileId}?alt=media`,
      {
        "method": "GET",
        "headers": {"Authorization": `Bearer ${token}`},
      },
    )
    if !response.ok {
      if response.status == 404 {
        throw(Errors.make(DriveFileNotFound, "Config file not found on Drive"))
      }
      throw(Errors.make(DriveNetworkError, `Drive API error: ${response.statusText}`))
    }
    let config: Types.containerToolboxConfig = await response->Browser.Fetch.jsonAs
    Nullable.make(config)
  }
}

let pushConfig = async (config: Types.containerToolboxConfig) => {
  let token = await getValidToken()
  let settings = await StorageManager.getSettings()
  let configJson = JSON.stringifyAny(config)->Option.getOr("{}")

  switch settings.driveFileId->Nullable.toOption {
  | Some(fileId) =>
    let response = await Browser.Fetch.fetch(
      `${driveUploadBase}/files/${fileId}?uploadType=media`,
      {
        "method": "PATCH",
        "headers": {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        "body": configJson,
      },
    )
    if !response.ok {
      throw(Errors.make(DriveNetworkError, `Failed to update file: ${response.statusText}`))
    }
  | None =>
    let metadata = JSON.stringifyAny({
      "name": settings.driveFileName,
      "mimeType": "application/json",
    })->Option.getOr("{}")

    let boundary = "container_toolbox_boundary"
    let body = `--${boundary}\r\nContent-Type: application/json\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Type: application/json\r\n\r\n${configJson}\r\n--${boundary}--`

    let response = await Browser.Fetch.fetch(
      `${driveUploadBase}/files?uploadType=multipart`,
      {
        "method": "POST",
        "headers": {
          "Authorization": `Bearer ${token}`,
          "Content-Type": `multipart/related; boundary=${boundary}`,
        },
        "body": body,
      },
    )
    if !response.ok {
      throw(Errors.make(DriveNetworkError, `Failed to create file: ${response.statusText}`))
    }

    let file: {"id": string} = await response->Browser.Fetch.jsonAs
    let current = await StorageManager.getSettings()
    let _ = await StorageManager.updateSettings({
      ...current,
      driveFileId: Nullable.make(file["id"]),
    })
  }
}

let deleteConfig = async () => {
  let settings = await StorageManager.getSettings()
  switch settings.driveFileId->Nullable.toOption {
  | Some(fileId) =>
    let token = await getValidToken()
    let _ = await Browser.Fetch.fetch(
      `${driveApiBase}/files/${fileId}`,
      {
        "method": "DELETE",
        "headers": {"Authorization": `Bearer ${token}`},
      },
    )
    let current = await StorageManager.getSettings()
    let _ = await StorageManager.updateSettings({
      ...current,
      driveFileId: Nullable.null,
    })
  | None => ()
  }
}
