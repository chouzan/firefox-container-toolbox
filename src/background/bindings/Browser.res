// Firefox WebExtension API bindings for ReScript

module ContextualIdentities = {
  type contextualIdentity = private {
    cookieStoreId: string,
    name: string,
    color: Constants.containerColor,
    icon: Constants.containerIcon,
  }

  type changeInfo = private {contextualIdentity: contextualIdentity}
  type updateDetails = {name?: string, color?: string, icon?: string}

  @scope(("browser", "contextualIdentities")) @val
  external create: {..} => promise<contextualIdentity> = "create"

  @scope(("browser", "contextualIdentities")) @val
  external queryAll: (@as(json`{}`) _, unit) => promise<array<contextualIdentity>> = "query"

  @scope(("browser", "contextualIdentities")) @val
  external update: (string, updateDetails) => promise<contextualIdentity> = "update"

  @scope(("browser", "contextualIdentities")) @val
  external remove: string => promise<contextualIdentity> = "remove"

  @scope(("browser", "contextualIdentities")) @val
  external move: (string, int) => promise<unit> = "move"

  module OnCreated = {
    @scope(("browser", "contextualIdentities", "onCreated")) @val
    external addListener: (changeInfo => unit) => unit = "addListener"
  }

  module OnRemoved = {
    @scope(("browser", "contextualIdentities", "onRemoved")) @val
    external addListener: (changeInfo => unit) => unit = "addListener"
  }

  module OnUpdated = {
    @scope(("browser", "contextualIdentities", "onUpdated")) @val
    external addListener: (changeInfo => unit) => unit = "addListener"
  }
}

module Storage = {
  @scope(("browser", "storage", "local")) @val
  external get: {..} => promise<{..}> = "get"

  @scope(("browser", "storage", "local")) @val
  external set: {..} => promise<unit> = "set"
}

module Runtime = {
  type messageSender = private {
    id?: string,
    url?: string,
  }

  @scope(("browser", "runtime")) @val
  external sendMessage: JSON.t => promise<JSON.t> = "sendMessage"

  @scope(("browser", "runtime")) @val
  external sendMessageToExtension: (string, JSON.t) => promise<JSON.t> = "sendMessage"

  @scope(("browser", "runtime")) @val
  external openOptionsPage: unit => promise<unit> = "openOptionsPage"

  module OnMessage = {
    type listener = (JSON.t, messageSender) => Nullable.t<promise<JSON.t>>

    @scope(("browser", "runtime", "onMessage")) @val
    external addListener: listener => unit = "addListener"
  }

  module OnInstalled = {
    type details = private {reason: string, previousVersion?: string}

    @scope(("browser", "runtime", "onInstalled")) @val
    external addListener: (details => unit) => unit = "addListener"
  }
}

module Identity = {
  @scope(("browser", "identity")) @val
  external launchWebAuthFlow: {..} => promise<string> = "launchWebAuthFlow"

  @scope(("browser", "identity")) @val
  external getRedirectURL: unit => string = "getRedirectURL"
}

module Downloads = {
  @scope(("browser", "downloads")) @val
  external download: {..} => promise<int> = "download"
}

module Notifications = {
  @scope(("browser", "notifications")) @val
  external create: (string, {..}) => promise<string> = "create"
}

module URL = {
  type t
  type searchParams

  @new external make: string => t = "URL"
  @get external searchParams: t => searchParams = "searchParams"
}

module URLSearchParams = {
  @send external get: (URL.searchParams, string) => Nullable.t<string> = "get"
}

module Crypto = {
  @scope("crypto") @val
  external randomUUID: unit => string = "randomUUID"
}

@val external encodeURIComponent: string => string = "encodeURIComponent"

module Fetch = {
  type response = private {
    ok: bool,
    status: int,
    statusText: string,
  }

  @send external json: response => promise<JSON.t> = "json"
  @send external jsonAs: response => promise<'a> = "json"
  @send external text: response => promise<string> = "text"

  @val external fetch: (string, {..}) => promise<response> = "fetch"
  @val external fetchUrl: string => promise<response> = "fetch"
}
