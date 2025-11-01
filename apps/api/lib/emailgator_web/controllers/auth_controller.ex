defmodule EmailgatorWeb.AuthController do
  use EmailgatorWeb, :controller
  alias Emailgator.Accounts
  alias Assent.Strategy.Google

  def request(conn, _params) do
    base_url = base_url(conn)
    redirect_uri = "#{base_url}/auth/google/callback"
    config = build_config(redirect_uri)

    case Google.authorize_url(config) do
      {:ok, %{url: url}} ->
        redirect(conn, external: url)

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to initiate OAuth flow: #{inspect(error)}"})
    end
  end

  def callback(conn, %{"code" => _code} = params) do
    base_url = base_url(conn)
    redirect_uri = "#{base_url}/auth/google/callback"
    config = build_config(redirect_uri)

    case Google.callback(config, params) do
      {:ok, %{user: user_params}} ->
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
        conn
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
    conn
    |> clear_session()
    |> json(%{ok: true})
  end

  defp base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    "#{scheme}://#{conn.host}:#{conn.port}"
  end

  defp build_config(redirect_uri) do
    assent_config = Application.get_env(:emailgator_api, :assent, [])
    provider_config = Keyword.get(assent_config, :providers, []) |> Keyword.get(:google, [])

    [
      client_id: Keyword.get(provider_config, :client_id),
      client_secret: Keyword.get(provider_config, :client_secret),
      redirect_uri: redirect_uri,
      authorization_params: [
        access_type: "offline",
        scope: "email profile"
      ]
    ]
  end
end
