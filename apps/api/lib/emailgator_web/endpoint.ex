defmodule EmailgatorWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :emailgator_api

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session,
    store: :cookie,
    key: "_emailgator_key",
    signing_salt:
      Application.compile_env(
        :emailgator_api,
        [EmailgatorWeb.Endpoint, :signing_salt],
        "emailgator_salt"
      ),
    encryption_salt:
      Application.compile_env(:emailgator_api, :cookie_enc_salt, "emailgator_enc_salt")
  )

  plug(EmailgatorWeb.Router)
end
