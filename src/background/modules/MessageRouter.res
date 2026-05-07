let handlers: Dict.t<JSON.t => promise<JSON.t>> = Dict.make()

let registerRaw = (action: string, handler: JSON.t => promise<JSON.t>) => {
  handlers->Dict.set(action, handler)
}

// Typed handler registration — the ONLY place type coercion happens.
let handle = (action: string, handler: 'payload => promise<'response>) => {
  registerRaw(action, payload => {
    let typed: 'payload = Obj.magic(payload)
    handler(typed)->Promise.thenResolve(result => {
      let json: JSON.t = Obj.magic(result)
      json
    })
  })
}

let handleUnit = (action: string, handler: unit => promise<'response>) => {
  registerRaw(action, _payload => {
    handler()->Promise.thenResolve(result => {
      let json: JSON.t = Obj.magic(result)
      json
    })
  })
}

let prefix = Constants.messagePrefix

let isOurMessage = (msg: JSON.t): bool => {
  switch msg->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Dict.get("type")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.map(t => t->String.startsWith(prefix))
    ->Option.getOr(false)
  | None => false
  }
}

let extractAction = (msg: JSON.t): string => {
  switch msg->JSON.Decode.object {
  | Some(obj) =>
    obj
    ->Dict.get("type")
    ->Option.flatMap(JSON.Decode.string)
    ->Option.map(t => t->String.slice(~start=prefix->String.length, ~end=t->String.length))
    ->Option.getOr("")
  | None => ""
  }
}

let getPayload = (msg: JSON.t): JSON.t => {
  switch msg->JSON.Decode.object {
  | Some(obj) => obj->Dict.get("payload")->Option.getOr(JSON.Null)
  | None => JSON.Null
  }
}

let makeOkResponse = (data: JSON.t): JSON.t => {
  JSON.Object(dict{"ok": JSON.Boolean(true), "data": data})
}

let makeErrResponse = (code: string, message: string): JSON.t => {
  JSON.Object(
    dict{
      "ok": JSON.Boolean(false),
      "error": JSON.Object(dict{"code": JSON.String(code), "message": JSON.String(message)}),
    },
  )
}

let setupMessageListener = () => {
  Browser.Runtime.OnMessage.addListener((message, _sender) => {
    if !isOurMessage(message) {
      Nullable.undefined
    } else {
      let action = extractAction(message)
      switch handlers->Dict.get(action) {
      | None =>
        Nullable.make(
          Promise.resolve(makeErrResponse("UNKNOWN_ACTION", `Unknown action: ${action}`)),
        )
      | Some(handler) =>
        Nullable.make(
          handler(getPayload(message))
          ->Promise.thenResolve(data => makeOkResponse(data))
          ->Promise.catch(err => {
            let errorInfo = Errors.toInfo(err)
            Promise.resolve(makeErrResponse((errorInfo.code :> string), errorInfo.message))
          }),
        )
      }
    }
  })
}
