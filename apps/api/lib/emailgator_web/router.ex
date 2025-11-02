defmodule EmailgatorWeb.Router do
  use EmailgatorWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:ensure_session_fetched)
    plug(EmailgatorWeb.Schema.Context)
  end

  defp ensure_session_fetched(conn, _opts) do
    Plug.Conn.fetch_session(conn)
  end

  scope "/api" do
    pipe_through(:api)

    forward("/graphql", Absinthe.Plug,
      schema: EmailgatorWeb.Schema,
      interface: :playground
    )

    forward("/graphiql", Absinthe.Plug.GraphiQL,
      schema: EmailgatorWeb.Schema,
      interface: :playground
    )
  end

  # OAuth routes (user sign-in)
  scope "/auth", EmailgatorWeb do
    pipe_through(:api)

    get("/google", AuthController, :request)
    get("/google/callback", AuthController, :callback)
    get("/logout", AuthController, :delete)
    post("/logout", AuthController, :delete)
  end

  # Gmail account connection routes (separate OAuth with Gmail scopes)
  scope "/gmail", EmailgatorWeb do
    pipe_through(:api)

    get("/connect", GmailController, :connect)
    get("/callback", GmailController, :callback)
  end

  # Health check endpoint (no auth required)
  get("/health", EmailgatorWeb.FallbackController, :health)
end
