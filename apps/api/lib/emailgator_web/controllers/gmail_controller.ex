defmodule EmailgatorWeb.GmailController do
  @moduledoc """
  Controller for connecting Gmail accounts (separate OAuth flow with Gmail scopes).
  """
  use EmailgatorWeb, :controller
  alias Emailgator.Accounts
  alias Assent.Strategy.Google

  def connect(conn, _params) do
    user_id = get_session(conn, :user_id)

    if is_nil(user_id) do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
    else
      base_url = base_url(conn)
      redirect_uri = "#{base_url}/gmail/callback"
      config = build_gmail_config(redirect_uri)

      require Logger
      Logger.info("🔍 Gmail OAuth Request - redirect_uri: #{redirect_uri}")

      case Google.authorize_url(config) do
        {:ok, %{url: url, session_params: session_params}} when is_list(session_params) ->
          # Convert keyword list to map before storing (Assent expects maps)
          session_map = Enum.into(session_params, %{})

          Logger.info(
            "🔍 Gmail - Storing session_params (converted to map): #{inspect(session_map)}"
          )

          conn
          |> put_session(:gmail_connect_user_id, user_id)
          |> put_session(:gmail_session_params, session_map)
          |> put_session(:gmail_redirect_uri, redirect_uri)
          |> redirect(external: url)

        {:ok, %{url: url, session_params: session_params}} when is_map(session_params) ->
          # Already a map, store directly
          Logger.info(
            "🔍 Gmail - Storing session_params (already map): #{inspect(session_params)}"
          )

          conn
          |> put_session(:gmail_connect_user_id, user_id)
          |> put_session(:gmail_session_params, session_params)
          |> put_session(:gmail_redirect_uri, redirect_uri)
          |> redirect(external: url)

        {:ok, %{url: url}} ->
          # If session_params not returned, Assent might handle state internally
          Logger.info("⚠️  Gmail - No session_params returned from authorize_url")

          conn
          |> put_session(:gmail_connect_user_id, user_id)
          |> put_session(:gmail_redirect_uri, redirect_uri)
          |> redirect(external: url)

        {:error, error} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to initiate Gmail OAuth: #{inspect(error)}"})
      end
    end
  end

  def callback(conn, %{"code" => _code} = params) do
    require Logger
    user_id = get_session(conn, :gmail_connect_user_id)

    if is_nil(user_id) do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Session expired"})
    else
      # Use the EXACT redirect_uri from the initial request (stored in session)
      redirect_uri = get_session(conn, :gmail_redirect_uri) || "#{base_url(conn)}/gmail/callback"

      Logger.info(
        "🔍 Gmail Callback - redirect_uri from session: #{inspect(get_session(conn, :gmail_redirect_uri))}"
      )

      Logger.info("🔍 Gmail Callback - redirect_uri being used: #{redirect_uri}")

      config = build_gmail_config(redirect_uri)

      # Retrieve session_params from session
      session_params = get_session(conn, :gmail_session_params)

      Logger.info("🔍 Gmail - Retrieved session_params from session: #{inspect(session_params)}")
      Logger.info("🔍 Gmail - Callback params: #{inspect(params)}")
      Logger.info("🔍 Gmail - State from URL: #{inspect(params["state"])}")

      # Convert session_params to map format (Assent expects a map, not keyword list)
      # ALWAYS ensure we have at least the state parameter for Assent
      final_session_params =
        cond do
          is_map(session_params) && map_size(session_params) > 0 ->
            Logger.info(
              "✅ Gmail - Using session_params map from session: #{inspect(session_params)}"
            )

            session_params

          is_list(session_params) && length(session_params) > 0 ->
            # Convert keyword list to map
            map = Enum.into(session_params, %{})
            Logger.info("✅ Gmail - Converted session_params keyword list to map: #{inspect(map)}")
            map

          params["state"] != nil ->
            # Fallback: use state from URL params - create as map
            state = params["state"]

            Logger.warning(
              "⚠️  Gmail - No session_params in session, using state from URL params: #{state}"
            )

            Logger.warning("⚠️  This may indicate session wasn't persisted across redirect")
            %{state: state}

          true ->
            Logger.error("❌ Gmail - No session_params and no state in params - cannot proceed")
            %{}
        end

      # CRITICAL: Assent REQUIRES session_params with at least 'state' key
      # Always merge session_params into config, using state from URL if session was lost
      callback_config =
        if map_size(final_session_params) > 0 do
          Logger.info(
            "✅ Gmail - Merging session_params into config: #{inspect(final_session_params)}"
          )

          Keyword.merge(config, session_params: final_session_params)
        else
          # Last resort: extract state from params and use it
          state_from_params = params["state"]

          if state_from_params do
            Logger.warning(
              "⚠️  Gmail - Session lost, using state from callback URL: #{state_from_params}"
            )

            Keyword.merge(config, session_params: %{state: state_from_params})
          else
            Logger.error("❌ Gmail - No state available - OAuth will fail!")
            Logger.error("❌ Config without session_params: #{inspect(config)}")
            config
          end
        end

      Logger.info(
        "🔍 Gmail Callback config has session_params: #{Keyword.has_key?(callback_config, :session_params)}"
      )

      Logger.info(
        "🔍 Gmail Callback config session_params value: #{inspect(Keyword.get(callback_config, :session_params))}"
      )

      case Google.callback(callback_config, params) do
        {:ok, %{user: user_params, token: token}} ->
          # Extract tokens from token map (Assent returns as map with string keys)
          access_token = Map.get(token, "access_token") || Map.get(token, :access_token)
          refresh_token = Map.get(token, "refresh_token") || Map.get(token, :refresh_token)

          if is_nil(access_token) or is_nil(refresh_token) do
            conn
            |> delete_session(:gmail_connect_user_id)
            |> delete_session(:gmail_session_params)
            |> delete_session(:gmail_redirect_uri)
            |> put_status(:internal_server_error)
            |> json(%{error: "OAuth callback missing tokens"})
          else
            # Get user's email from user_params
            email = user_params["email"] || user_params["email_address"]
            expires_at = calculate_expires_at(token)

            # Create or update Gmail account
            case Accounts.get_account_by_email(user_id, email) do
              nil ->
                Accounts.create_account(%{
                  user_id: user_id,
                  email: email,
                  access_token: access_token,
                  refresh_token: refresh_token,
                  expires_at: expires_at
                })

              existing_account ->
                Accounts.update_account(existing_account, %{
                  access_token: access_token,
                  refresh_token: refresh_token,
                  expires_at: expires_at
                })
            end
            |> case do
              {:ok, _account} ->
                frontend_url = System.get_env("FRONTEND_URL") || "http://localhost:3000"
                redirect_url = "#{frontend_url}?gmail=connected"

                conn
                |> delete_session(:gmail_connect_user_id)
                |> delete_session(:gmail_session_params)
                |> delete_session(:gmail_redirect_uri)
                |> redirect(external: redirect_url)

              {:error, changeset} ->
                conn
                |> delete_session(:gmail_connect_user_id)
                |> delete_session(:gmail_session_params)
                |> delete_session(:gmail_redirect_uri)
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Failed to connect account: #{inspect(changeset.errors)}"})
            end
          end

        {:error, error} ->
          conn
          |> delete_session(:gmail_connect_user_id)
          |> delete_session(:gmail_session_params)
          |> delete_session(:gmail_redirect_uri)
          |> put_status(:internal_server_error)
          |> json(%{error: "OAuth callback failed: #{inspect(error)}"})
      end
    end
  end

  def callback(conn, %{"error" => error, "error_description" => description}) do
    conn
    |> delete_session(:gmail_connect_user_id)
    |> delete_session(:gmail_session_params)
    |> delete_session(:gmail_redirect_uri)
    |> put_status(:bad_request)
    |> json(%{error: error, description: description})
  end

  def callback(conn, _params) do
    conn
    |> delete_session(:gmail_connect_user_id)
    |> delete_session(:gmail_session_params)
    |> delete_session(:gmail_redirect_uri)
    |> put_status(:bad_request)
    |> json(%{error: "Missing code parameter"})
  end

  defp base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port_str = if conn.port == 80 or conn.port == 443, do: "", else: ":#{conn.port}"
    "#{scheme}://#{conn.host}#{port_str}"
  end

  defp build_gmail_config(redirect_uri) do
    assent_config = Application.get_env(:emailgator_api, :assent, [])
    provider_config = Keyword.get(assent_config, :providers, []) |> Keyword.get(:google, [])

    [
      client_id: Keyword.get(provider_config, :client_id),
      client_secret: Keyword.get(provider_config, :client_secret),
      redirect_uri: redirect_uri,
      authorization_params: [
        access_type: "offline",
        prompt: "consent",
        scope:
          "email profile https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.modify"
      ]
    ]
  end

  defp calculate_expires_at(token) do
    # Get expires_in from token, default to 3600 seconds (1 hour)
    expires_in =
      Map.get(token, "expires_in") ||
        Map.get(token, :expires_in) ||
        3600

    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end
end
