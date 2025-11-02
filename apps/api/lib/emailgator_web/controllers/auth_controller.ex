defmodule EmailgatorWeb.AuthController do
  use EmailgatorWeb, :controller
  alias Emailgator.Accounts
  alias Assent.Strategy.Google

  def request(conn, _params) do
    # Use configured redirect_uri or construct from connection
    # IMPORTANT: Must match exactly what's registered in Google Console
    redirect_uri = get_redirect_uri(conn)
    config = build_config(redirect_uri)

    require Logger
    Logger.info("🔍 OAuth Request - redirect_uri: #{redirect_uri}")
    Logger.info("🔍 OAuth Request - base_url from conn: #{base_url(conn)}")
    Logger.info("🔍 OAuth Request - GOOGLE_OAUTH_REDIRECT_URL env: #{inspect(System.get_env("GOOGLE_OAUTH_REDIRECT_URL"))}")

    case Google.authorize_url(config) do
      {:ok, %{url: url, session_params: session_params}} when is_list(session_params) ->
        # Convert keyword list to map before storing (Assent expects maps)
        session_map = Enum.into(session_params, %{})
        Logger.info("🔍 Storing session_params (converted to map): #{inspect(session_map)}")
        conn
        |> put_session(:oauth_session_params, session_map)
        |> put_session(:oauth_redirect_uri, redirect_uri)  # Store redirect_uri for callback
        |> redirect(external: url)

      {:ok, %{url: url, session_params: session_params}} when is_map(session_params) ->
        # Already a map, store directly
        Logger.info("🔍 Storing session_params (already map): #{inspect(session_params)}")
        conn
        |> put_session(:oauth_session_params, session_params)
        |> put_session(:oauth_redirect_uri, redirect_uri)  # Store redirect_uri for callback
        |> redirect(external: url)

      {:ok, %{url: url}} ->
        # If session_params not returned, Assent might handle state internally
        Logger.info("⚠️  No session_params returned from authorize_url")
        conn
        |> put_session(:oauth_redirect_uri, redirect_uri)  # Store redirect_uri for callback
        |> redirect(external: url)

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to initiate OAuth flow: #{inspect(error)}"})
    end
  end

  def callback(conn, %{"code" => _code} = params) do
    # Check if authorization code might be reused (single-use only!)
    require Logger

    # Use the EXACT redirect_uri from the initial request (stored in session)
    # This ensures it matches what Google has in its token exchange
    redirect_uri = get_session(conn, :oauth_redirect_uri) || get_redirect_uri(conn)

    # Warn if session is missing - might indicate code reuse
    if get_session(conn, :oauth_redirect_uri) == nil do
      Logger.warning("⚠️  No session found - this might be a reused authorization code. Authorization codes are single-use and expire quickly.")
      Logger.warning("⚠️  If you're seeing 'invalid_grant', you need to start a fresh OAuth flow from the beginning.")
    end

    require Logger
    Logger.info("🔍 OAuth Callback - redirect_uri from session: #{inspect(get_session(conn, :oauth_redirect_uri))}")
    Logger.info("🔍 OAuth Callback - redirect_uri being used: #{redirect_uri}")
    Logger.info("🔍 OAuth Callback - base_url from conn: #{base_url(conn)}")
    Logger.info("🔍 OAuth Callback - GOOGLE_OAUTH_REDIRECT_URL env: #{inspect(System.get_env("GOOGLE_OAUTH_REDIRECT_URL"))}")

    config = build_config(redirect_uri)

    # Retrieve session_params from session
    session_params = get_session(conn, :oauth_session_params)

    require Logger
    Logger.info("🔍 Retrieved session_params from session: #{inspect(session_params)}")
    Logger.info("🔍 OAuth callback params: #{inspect(params)}")

    # Convert session_params to map format (Assent expects a map, not keyword list)
    # Phoenix sessions might store as keyword list, so convert to map
    final_session_params = cond do
      is_map(session_params) && map_size(session_params) > 0 ->
        Logger.info("✅ Using session_params map from session: #{inspect(session_params)}")
        session_params

      is_list(session_params) && length(session_params) > 0 ->
        # Convert keyword list to map
        map = Enum.into(session_params, %{})
        Logger.info("✅ Converted session_params keyword list to map: #{inspect(map)}")
        map

      params["state"] != nil ->
        # Fallback: use state from URL params - create as map
        state = params["state"]
        Logger.warning("⚠️  No session_params found, using state from URL params: #{state}")
        %{state: state}

      true ->
        Logger.error("❌ No session_params and no state in params - OAuth flow may fail")
        %{}
    end

    # Merge session_params into config (only if not empty)
    callback_config = if map_size(final_session_params) > 0 do
      Keyword.merge(config, session_params: final_session_params)
    else
      config
    end

    # Debug: Log the complete callback config being sent to Google
    Logger.info("🔍 Callback config: client_id = #{inspect(Keyword.get(callback_config, :client_id))}")
    Logger.info("🔍 Callback config: redirect_uri = #{inspect(Keyword.get(callback_config, :redirect_uri))}")
    Logger.info("🔍 Callback config: has session_params = #{map_size(final_session_params) > 0}")

    case Google.callback(callback_config, params) do
      {:ok, %{user: user_params}} ->
        # Clear OAuth session params after successful callback
        conn = delete_session(conn, :oauth_session_params)

        case Accounts.create_or_update_user(user_params) do
          {:ok, user} ->
            frontend_url = System.get_env("FRONTEND_URL") || "http://localhost:3000"
            redirect_url = "#{frontend_url}?auth=success"

            conn
            |> put_session(:user_id, user.id)
            |> put_session(:user_email, user.email)
            |> redirect(external: redirect_url)

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to create user: #{inspect(changeset.errors)}"})
        end

      {:error, error} ->
        # Clear session params on error
        conn
        |> delete_session(:oauth_session_params)
        |> put_status(:internal_server_error)
        |> json(%{error: "OAuth callback failed: #{inspect(error)}"})
    end
  end

  def callback(conn, %{"error" => error, "error_description" => description}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: error, description: description})
  end

  def callback(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing code parameter"})
  end

  def delete(conn, _params) do
    frontend_url = System.get_env("FRONTEND_URL") || "http://localhost:3000"

    conn
    |> clear_session()
    |> redirect(external: frontend_url)
  end

  defp base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port_str = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"
    "#{scheme}://#{conn.host}#{port_str}"
  end

  defp get_redirect_uri(conn) do
    # Use configured redirect_uri from env if available, otherwise construct from connection
    case System.get_env("GOOGLE_OAUTH_REDIRECT_URL") do
      nil ->
        base_url = base_url(conn)
        "#{base_url}/auth/google/callback"
      configured_uri ->
        configured_uri
    end
  end

  defp build_config(redirect_uri) do
    assent_config = Application.get_env(:emailgator_api, :assent, [])
    provider_config = Keyword.get(assent_config, :providers, []) |> Keyword.get(:google, [])

    # Debug: Log the client_id being used
    client_id = Keyword.get(provider_config, :client_id)
    require Logger
    Logger.info("🔍 OAuth Config Debug: client_id = #{inspect(client_id)}")
    Logger.info("🔍 OAuth Config Debug: redirect_uri = #{redirect_uri}")

    Logger.info(
      "🔍 OAuth Config Debug: ENV GOOGLE_CLIENT_ID = #{inspect(System.get_env("GOOGLE_CLIENT_ID"))}"
    )

    [
      client_id: client_id,
      client_secret: Keyword.get(provider_config, :client_secret),
      redirect_uri: redirect_uri,
      authorization_params: [
        access_type: "offline",
        scope: "email profile"
      ]
    ]
  end
end
