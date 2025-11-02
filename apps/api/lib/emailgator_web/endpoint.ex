defmodule EmailgatorWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :emailgator_api

  import Plug.Conn

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # CORS support for frontend (localhost:3000)
  plug(:cors)

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
    # Note: same_site option removed - CORS headers handle cross-origin cookie sharing
  )

  plug(EmailgatorWeb.Router)

  # CORS plug handler
  defp cors(conn, _opts) do
    frontend_url = System.get_env("FRONTEND_URL") || "http://localhost:3000"
    origin = List.first(get_req_header(conn, "origin")) || frontend_url

    # Handle OPTIONS preflight requests
    if conn.method == "OPTIONS" do
      conn
      |> put_resp_header("access-control-allow-origin", origin)
      |> put_resp_header("access-control-allow-credentials", "true")
      |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
      |> put_resp_header("access-control-max-age", "3600")
      |> send_resp(:no_content, "")
      |> halt()
    else
      # Allow requests from frontend URL or any origin in dev
      allowed_origin =
        cond do
          origin == frontend_url -> frontend_url
          Mix.env() == :dev -> origin
          true -> frontend_url
        end

      conn
      |> put_resp_header("access-control-allow-origin", allowed_origin)
      |> put_resp_header("access-control-allow-credentials", "true")
      |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "Content-Type, Authorization")
    end
  end
end
