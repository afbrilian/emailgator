defmodule Emailgator.Gmail do
  @moduledoc """
  Gmail API client using Tesla.
  """
  use Tesla
  alias Emailgator.Accounts.Account

  plug(Tesla.Middleware.BaseUrl, "https://gmail.googleapis.com/gmail/v1")
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 5)

  @doc """
  List new messages for an account using history API.
  Returns list of message IDs that are new since last_history_id.
  """
  def list_new_message_ids(%Account{} = account) do
    case account.last_history_id do
      nil ->
        # First time - get all messages
        list_recent_messages(account)

      history_id ->
        # Get messages since last history ID
        list_history(account, history_id)
    end
  end

  @doc """
  Get message metadata and body.
  """
  def get_message(account_id, message_id) do
    headers = auth_headers(account_id)

    case get("/users/me/messages/#{message_id}", headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, "Gmail API error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Archive a message in Gmail.
  """
  def archive_message(account_id, message_id) do
    headers = auth_headers(account_id)

    case post(
           "/users/me/messages/#{message_id}/modify",
           %{removeLabelIds: ["INBOX"]},
           headers: headers
         ) do
      {:ok, %Tesla.Env{status: 200}} ->
        {:ok, :archived}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, "Failed to archive: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Refresh access token using refresh token.
  """
  def refresh_token(%Account{} = account) do
    url = "https://oauth2.googleapis.com/token"
    client = Tesla.client([Tesla.Middleware.JSON])

    body = %{
      client_id: System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
      refresh_token: account.refresh_token,
      grant_type: "refresh_token"
    }

    case Tesla.post(client, url, body) do
      {:ok, %Tesla.Env{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
        expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)
        {:ok, token, expires_at}

      {:ok, %Tesla.Env{body: body}} ->
        {:error, "Token refresh failed: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp list_recent_messages(%Account{} = account) do
    headers = auth_headers(account.id)

    case get("/users/me/messages?maxResults=50&q=in:inbox", headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: %{"messages" => messages}}} ->
        message_ids = Enum.map(messages || [], & &1["id"])
        {:ok, message_ids, nil}

      {:ok, %Tesla.Env{status: status}} ->
        {:error, "Failed to list messages: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp list_history(%Account{} = account, history_id) do
    headers = auth_headers(account.id)

    case get(
           "/users/me/history?historyTypes=messageAdded&startHistoryId=#{history_id}",
           headers: headers
         ) do
      {:ok, %Tesla.Env{status: 200, body: %{"history" => history}}} ->
        message_ids =
          history
          |> Enum.flat_map(&(&1["messagesAdded"] || []))
          |> Enum.map(& &1["message"]["id"])
          |> Enum.uniq()

        new_history_id = extract_latest_history_id(history)
        {:ok, message_ids, new_history_id}

      {:ok, %Tesla.Env{status: 404}} ->
        # History ID not found, start fresh
        list_recent_messages(account)

      {:ok, %Tesla.Env{status: status}} ->
        {:error, "Failed to get history: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_latest_history_id(history) when is_list(history) and length(history) > 0 do
    history
    |> Enum.map(& &1["id"])
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      ids -> Enum.max(ids)
    end
  end

  defp extract_latest_history_id(_), do: nil

  defp auth_headers(account_id) do
    case Emailgator.Accounts.get_account_with_valid_token(account_id) do
      {:ok, account} -> [{"Authorization", "Bearer #{account.access_token}"}]
      _ -> []
    end
  end
end
