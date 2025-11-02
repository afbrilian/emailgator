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

      case Google.authorize_url(config) do
        {:ok, %{url: url}} ->
          # Store redirect info in session
          conn
          |> put_session(:gmail_connect_user_id, user_id)
          |> redirect(external: url)

        {:error, error} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to initiate Gmail OAuth: #{inspect(error)}"})
      end
    end
  end

  def callback(conn, %{"code" => _code} = params) do
    user_id = get_session(conn, :gmail_connect_user_id)

    if is_nil(user_id) do
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Session expired"})
    else
      base_url = base_url(conn)
      redirect_uri = "#{base_url}/gmail/callback"
      config = build_gmail_config(redirect_uri)

      case Google.callback(config, params) do
        {:ok, %{user: user_params, token: token}} ->
          # Extract tokens from token map (Assent returns as map with string keys)
          access_token = Map.get(token, "access_token") || Map.get(token, :access_token)
          refresh_token = Map.get(token, "refresh_token") || Map.get(token, :refresh_token)

          if is_nil(access_token) or is_nil(refresh_token) do
            conn
            |> delete_session(:gmail_connect_user_id)
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
                |> redirect(external: redirect_url)

              {:error, changeset} ->
                conn
                |> delete_session(:gmail_connect_user_id)
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Failed to connect account: #{inspect(changeset.errors)}"})
            end
          end

        {:error, error} ->
          conn
          |> delete_session(:gmail_connect_user_id)
          |> put_status(:internal_server_error)
          |> json(%{error: "OAuth callback failed: #{inspect(error)}"})
      end
    end
  end

  def callback(conn, %{"error" => error, "error_description" => description}) do
    conn
    |> delete_session(:gmail_connect_user_id)
    |> put_status(:bad_request)
    |> json(%{error: error, description: description})
  end

  def callback(conn, _params) do
    conn
    |> delete_session(:gmail_connect_user_id)
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
