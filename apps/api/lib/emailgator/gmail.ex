defmodule Emailgator.Gmail do
  @moduledoc """
  Gmail API client using Tesla.
  """
  use Tesla
  alias Emailgator.Accounts.Account

  adapter(Tesla.Adapter.Finch, name: Emailgator.Finch)

  plug(Tesla.Middleware.BaseUrl, "https://gmail.googleapis.com/gmail/v1")
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 5)

  @doc """
  List new messages for an account using history API.
  Returns list of message IDs that are new since last_history_id.
  """
  def list_new_message_ids(%Account{} = account) do
    require Logger

    Logger.info(
      "Gmail.list_new_message_ids: Called for account #{account.id}, last_history_id: #{inspect(account.last_history_id)}"
    )

    result =
      case account.last_history_id do
        nil ->
          # First time - get all messages
          Logger.info("Gmail.list_new_message_ids: No history_id, fetching recent messages")
          list_recent_messages(account)

        history_id ->
          # Get messages since last history ID
          Logger.info("Gmail.list_new_message_ids: Using history_id #{history_id}")
          list_history(account, history_id)
      end

    case result do
      {:ok, _, _} = ok ->
        ok

      {:error, reason} = error ->
        Logger.error(
          "Gmail.list_new_message_ids: Error for account #{account.id}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Get message metadata and body.
  """
  def get_message(account_id, message_id) do
    require Logger
    Logger.info("Gmail.get_message: Fetching message #{message_id} for account #{account_id}")

    headers = auth_headers(account_id)

    if Enum.empty?(headers) do
      Logger.error("Gmail.get_message: No auth headers - cannot make request")
      {:error, "Authentication failed: no valid access token"}
    else
      Logger.info("Gmail.get_message: Making API request with auth headers (timeout: 15s)")

      # Use Task with timeout to prevent hanging requests
      task =
        Task.async(fn ->
          try do
            result = get("/users/me/messages/#{message_id}", headers: headers)
            Logger.debug("Gmail.get_message: Request completed in Task")
            result
          rescue
            e ->
              Logger.error("Gmail.get_message: Exception in Task: #{inspect(e)}")
              {:error, inspect(e)}
          catch
            :exit, reason ->
              Logger.error("Gmail.get_message: Task exited: #{inspect(reason)}")
              {:error, inspect(reason)}
          end
        end)

      Logger.debug("Gmail.get_message: Waiting for Task with 15s timeout...")

      result =
        case Task.yield(task, 15_000) || Task.shutdown(task) do
          {:ok, {:ok, %Tesla.Env{status: 200, body: body}}} ->
            Logger.info("Gmail.get_message: Successfully fetched message #{message_id}")
            {:ok, body}

          {:ok, {:ok, %Tesla.Env{status: status, body: body}}} ->
            Logger.error(
              "Gmail.get_message: Failed to get message: status #{status}, body: #{inspect(body)}"
            )

            {:error, "Gmail API error: #{status}"}

          {:ok, {:error, reason}} ->
            Logger.error("Gmail.get_message: Request error: #{inspect(reason)}")
            {:error, reason}

          nil ->
            Logger.error("Gmail.get_message: Request timed out after 15 seconds")
            {:error, "Request timed out"}

          {:exit, reason} ->
            Logger.error("Gmail.get_message: Task exited: #{inspect(reason)}")
            {:error, "Request task failed"}
        end

      Logger.debug("Gmail.get_message: Task result: #{inspect(result)}")
      result
    end
  end

  @doc """
  Archive a message in Gmail.
  """
  def archive_message(account_id, message_id) do
    require Logger

    Logger.info(
      "Gmail.archive_message: Archiving message #{message_id} for account #{account_id}"
    )

    headers = auth_headers(account_id)

    if Enum.empty?(headers) do
      Logger.error("Gmail.archive_message: No auth headers - cannot make request")
      {:error, "Authentication failed: no valid access token"}
    else
      Logger.info("Gmail.archive_message: Making API request with auth headers (timeout: 15s)")

      # Use Task with timeout to prevent hanging requests
      task =
        Task.async(fn ->
          try do
            result =
              post(
                "/users/me/messages/#{message_id}/modify",
                %{removeLabelIds: ["INBOX"]},
                headers: headers
              )

            Logger.debug("Gmail.archive_message: Request completed in Task")
            result
          rescue
            e ->
              Logger.error("Gmail.archive_message: Exception in Task: #{inspect(e)}")
              {:error, inspect(e)}
          catch
            :exit, reason ->
              Logger.error("Gmail.archive_message: Task exited: #{inspect(reason)}")
              {:error, inspect(reason)}
          end
        end)

      Logger.debug("Gmail.archive_message: Waiting for Task with 15s timeout...")

      result =
        case Task.yield(task, 15_000) || Task.shutdown(task) do
          {:ok, {:ok, %Tesla.Env{status: 200}}} ->
            Logger.info("Gmail.archive_message: Successfully archived message #{message_id}")
            {:ok, :archived}

          {:ok, {:ok, %Tesla.Env{status: status, body: body}}} ->
            Logger.error(
              "Gmail.archive_message: Failed to archive: status #{status}, body: #{inspect(body)}"
            )

            {:error, "Failed to archive: #{status}"}

          {:ok, {:error, reason}} ->
            Logger.error("Gmail.archive_message: Request error: #{inspect(reason)}")
            {:error, reason}

          nil ->
            Logger.error("Gmail.archive_message: Request timed out after 15 seconds")
            {:error, "Request timed out"}

          {:exit, reason} ->
            Logger.error("Gmail.archive_message: Task exited: #{inspect(reason)}")
            {:error, "Request task failed"}
        end

      Logger.debug("Gmail.archive_message: Task result: #{inspect(result)}")
      result
    end
  end

  @doc """
  Refresh access token using refresh token.
  Uses Finch directly for OAuth token refresh (simpler than Tesla for this case).
  """
  def refresh_token(%Account{} = account) do
    require Logger
    Logger.info("Gmail.refresh_token: Starting token refresh for account #{account.id}")

    url = "https://oauth2.googleapis.com/token"
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    client_secret = System.get_env("GOOGLE_CLIENT_SECRET")

    Logger.debug(
      "Gmail.refresh_token: Using client_id: #{if client_id, do: String.slice(client_id, 0..10) <> "...", else: "nil"}"
    )

    if is_nil(account.refresh_token) do
      Logger.error("Gmail.refresh_token: Account #{account.id} has no refresh_token")
      {:error, "No refresh token available"}
    else
      if is_nil(client_id) or is_nil(client_secret) do
        Logger.error("Gmail.refresh_token: Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET")
        {:error, "Missing OAuth credentials"}
      else
        # Build form-encoded body for OAuth token refresh
        body =
          URI.encode_query(%{
            "client_id" => client_id,
            "client_secret" => client_secret,
            "refresh_token" => account.refresh_token,
            "grant_type" => "refresh_token"
          })

        headers = [{"content-type", "application/x-www-form-urlencoded"}]

        Logger.info("Gmail.refresh_token: Making POST request to #{url} (timeout: 10s)")

        # Use Task with timeout to prevent hanging requests
        task =
          Task.async(fn ->
            Finch.build(:post, url, headers, body)
            |> Finch.request(Emailgator.Finch, receive_timeout: 10_000)
          end)

        case Task.yield(task, 10_000) || Task.shutdown(task) do
          {:ok, {:ok, %Finch.Response{status: 200, body: body_json}}} ->
            case Jason.decode(body_json) do
              {:ok, %{"access_token" => token, "expires_in" => expires_in}} ->
                Logger.info("Gmail.refresh_token: Token refresh successful")
                expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)
                {:ok, token, expires_at}

              {:ok, body_map} ->
                Logger.error(
                  "Gmail.refresh_token: Unexpected response body: #{inspect(body_map)}"
                )

                {:error, "Token refresh failed: unexpected response format"}

              {:error, decode_error} ->
                Logger.error(
                  "Gmail.refresh_token: Failed to decode JSON response: #{inspect(decode_error)}"
                )

                {:error, "Token refresh failed: invalid JSON response"}
            end

          {:ok, {:ok, %Finch.Response{status: status, body: body_json}}} ->
            case Jason.decode(body_json) do
              {:ok, body_map} ->
                Logger.error(
                  "Gmail.refresh_token: Token refresh failed with status #{status}: #{inspect(body_map)}"
                )

                {:error, "Token refresh failed: #{inspect(body_map)}"}

              {:error, _} ->
                Logger.error(
                  "Gmail.refresh_token: Token refresh failed with status #{status}: #{body_json}"
                )

                {:error, "Token refresh failed: status #{status}"}
            end

          {:ok, {:error, reason}} ->
            Logger.error("Gmail.refresh_token: Request error: #{inspect(reason)}")
            {:error, reason}

          nil ->
            Logger.error("Gmail.refresh_token: Request timed out after 10 seconds")
            {:error, "Token refresh timed out"}

          {:exit, reason} ->
            Logger.error("Gmail.refresh_token: Task exited: #{inspect(reason)}")
            {:error, "Token refresh task failed"}
        end
      end
    end
  end

  # Private helpers

  defp list_recent_messages(%Account{} = account) do
    require Logger
    Logger.info("Gmail.list_recent_messages: Fetching recent messages for account #{account.id}")

    headers = auth_headers(account.id)

    if Enum.empty?(headers) do
      Logger.error("Gmail.list_recent_messages: No auth headers - cannot make request")
      {:error, "Authentication failed: no valid access token"}
    else
      Logger.info(
        "Gmail.list_recent_messages: Making API request with auth headers (timeout: 15s)"
      )

      # Use Task with timeout to prevent hanging requests
      task =
        Task.async(fn ->
          try do
            result = get("/users/me/messages?maxResults=5&q=in:inbox", headers: headers)
            Logger.debug("Gmail.list_recent_messages: Request completed in Task")
            result
          rescue
            e ->
              Logger.error("Gmail.list_recent_messages: Exception in Task: #{inspect(e)}")
              {:error, inspect(e)}
          catch
            :exit, reason ->
              Logger.error("Gmail.list_recent_messages: Task exited: #{inspect(reason)}")
              {:error, inspect(reason)}
          end
        end)

      Logger.debug("Gmail.list_recent_messages: Waiting for Task with 15s timeout...")

      result =
        case Task.yield(task, 15_000) || Task.shutdown(task) do
          {:ok, {:ok, %Tesla.Env{status: 200, body: body}}} ->
            messages = body["messages"] || []
            message_ids = Enum.map(messages, & &1["id"]) |> Enum.reject(&is_nil/1)

            Logger.info(
              "Gmail.list_recent_messages: Found #{length(message_ids)} message(s) in inbox"
            )

            {:ok, message_ids, nil}

          {:ok, {:ok, %Tesla.Env{status: status, body: body}}} ->
            Logger.error(
              "Gmail.list_recent_messages: Failed to list messages: status #{status}, body: #{inspect(body)}"
            )

            {:error, "Failed to list messages: #{status}"}

          {:ok, {:error, reason}} ->
            Logger.error("Gmail.list_recent_messages: Request error: #{inspect(reason)}")
            {:error, reason}

          nil ->
            Logger.error("Gmail.list_recent_messages: Request timed out after 15 seconds")
            {:error, "Request timed out"}

          {:exit, reason} ->
            Logger.error("Gmail.list_recent_messages: Task exited: #{inspect(reason)}")
            {:error, "Request task failed"}
        end

      Logger.debug("Gmail.list_recent_messages: Task result: #{inspect(result)}")
      result
    end
  end

  defp list_history(%Account{} = account, history_id) do
    require Logger

    Logger.info(
      "Gmail.list_history: Fetching history since history_id: #{history_id} for account #{account.id}"
    )

    headers = auth_headers(account.id)

    if Enum.empty?(headers) do
      Logger.error("Gmail.list_history: No auth headers - cannot make request")
      {:error, "Authentication failed: no valid access token"}
    else
      Logger.info("Gmail.list_history: Making API request with auth headers (timeout: 15s)")

      # Use Task with timeout to prevent hanging requests
      task =
        Task.async(fn ->
          try do
            result =
              get(
                "/users/me/history?historyTypes=messageAdded&startHistoryId=#{history_id}",
                headers: headers
              )

            Logger.debug("Gmail.list_history: Request completed in Task")
            result
          rescue
            e ->
              Logger.error("Gmail.list_history: Exception in Task: #{inspect(e)}")
              {:error, inspect(e)}
          catch
            :exit, reason ->
              Logger.error("Gmail.list_history: Task exited: #{inspect(reason)}")
              {:error, inspect(reason)}
          end
        end)

      Logger.debug("Gmail.list_history: Waiting for Task with 15s timeout...")

      result =
        case Task.yield(task, 15_000) || Task.shutdown(task) do
          {:ok, {:ok, %Tesla.Env{status: 200, body: body}}} ->
            history = body["history"] || []
            Logger.info("Gmail.list_history: Received #{length(history)} history entry(ies)")

            message_ids =
              history
              |> Enum.flat_map(&(&1["messagesAdded"] || []))
              |> Enum.map(& &1["message"]["id"])
              |> Enum.reject(&is_nil/1)
              |> Enum.uniq()

            new_history_id = extract_latest_history_id(history) || history_id

            Logger.info(
              "Gmail.list_history: Found #{length(message_ids)} new message(s), using history_id: #{new_history_id}"
            )

            {:ok, message_ids, new_history_id}

          {:ok, {:ok, %Tesla.Env{status: 404}}} ->
            Logger.warning(
              "Gmail.list_history: History ID #{history_id} not found (expired), starting fresh"
            )

            # History ID not found, start fresh
            list_recent_messages(account)

          {:ok, {:ok, %Tesla.Env{status: status, body: body}}} ->
            Logger.error(
              "Gmail.list_history: Failed to get history: status #{status}, body: #{inspect(body)}"
            )

            {:error, "Failed to get history: #{status}"}

          {:ok, {:error, reason}} ->
            Logger.error("Gmail.list_history: Request error: #{inspect(reason)}")
            {:error, reason}

          nil ->
            Logger.error("Gmail.list_history: Request timed out after 15 seconds")
            {:error, "Request timed out"}

          {:exit, reason} ->
            Logger.error("Gmail.list_history: Task exited: #{inspect(reason)}")
            {:error, "Request task failed"}
        end

      Logger.debug("Gmail.list_history: Task result: #{inspect(result)}")
      result
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
    require Logger
    Logger.info("Gmail.auth_headers: Called for account_id: #{account_id}, getting token...")

    case Emailgator.Accounts.get_account_with_valid_token(account_id) do
      {:ok, account} ->
        if account.access_token do
          Logger.info("Gmail.auth_headers: Got valid token for account #{account_id}")
          [{"Authorization", "Bearer #{account.access_token}"}]
        else
          Logger.error("Gmail.auth_headers: Account #{account_id} has no access_token")
          []
        end

      {:error, reason} ->
        Logger.error(
          "Gmail.auth_headers: Failed to get valid token for account #{account_id}: #{inspect(reason)}"
        )

        []

      nil ->
        Logger.error("Gmail.auth_headers: Account #{account_id} not found")
        []
    end
  end
end
