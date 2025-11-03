defmodule Emailgator.GmailComprehensiveTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.Gmail
  alias Emailgator.Accounts

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    System.put_env("GOOGLE_CLIENT_ID", "test_client_id")
    System.put_env("GOOGLE_CLIENT_SECRET", "test_client_secret")

    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
    end)

    :ok
  end

  describe "get_message/2" do
    test "handles successful message retrieval" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages/") ->
              mock_json(%{
                "id" => "msg123",
                "threadId" => "thread123",
                "labelIds" => ["INBOX"],
                "snippet" => "Test email",
                "payload" => %{
                  "headers" => [
                    %{"name" => "From", "value" => "test@example.com"},
                    %{"name" => "Subject", "value" => "Test"}
                  ]
                }
              })

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.get_message(account.id, "msg123")
      assert {:ok, message} = result
      assert message["id"] == "msg123"
    end

    test "handles 404 response" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get} ->
          %Tesla.Env{status: 404, body: %{"error" => "Not found"}}
      end)

      result = Gmail.get_message(account.id, "nonexistent_message_id")
      assert {:error, _reason} = result
    end

    test "handles non-200 status" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get} ->
          %Tesla.Env{status: 403, body: %{"error" => "Forbidden"}}
      end)

      result = Gmail.get_message(account.id, "msg123")
      assert {:error, _reason} = result
    end
  end

  describe "archive_message/2" do
    test "successfully archives message" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :post} ->
          mock_json(%{"id" => "msg123", "labelIds" => []})
      end)

      result = Gmail.archive_message(account.id, "msg123")
      assert {:ok, _response} = result
    end

    test "handles 403 forbidden response" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :post} ->
          %Tesla.Env{status: 403, body: %{"error" => "Forbidden"}}
      end)

      result = Gmail.archive_message(account.id, "msg123")
      assert {:error, _reason} = result
    end
  end

  describe "list_new_message_ids/1" do
    test "handles empty messages response" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: nil,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") ->
              mock_json(%{"messages" => []})

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "new_history"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, message_ids, _history_id} = result
      assert message_ids == []
    end

    test "handles messages without IDs" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: nil,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") ->
              mock_json(%{"messages" => [%{}, %{"id" => "msg2"}]})

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "new_history"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, message_ids, _history_id} = result
      assert message_ids == ["msg2"]
    end

    test "handles history fallback when history_id not found" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: "expired_history_id",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "history") ->
              %Tesla.Env{status: 404, body: %{"error" => "History ID not found"}}

            String.contains?(url, "/users/me/messages") and String.contains?(url, "in:inbox") ->
              mock_json(%{"messages" => [%{"id" => "msg1"}]})

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "new_history"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      # Should fallback to list_recent_messages
      assert {:ok, message_ids, _history_id} = result
      assert "msg1" in message_ids
    end

    test "handles history with messagesAdded but missing message.id" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: "100",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "history") ->
              mock_json(%{
                "history" => [
                  %{
                    "id" => "101",
                    "messagesAdded" => [
                      # Missing id
                      %{"message" => %{}},
                      %{"message" => %{"id" => "msg123"}}
                    ]
                  }
                ]
              })

            String.contains?(url, "profile") ->
              mock_json(%{"historyId" => "102"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, message_ids, _history_id} = result
      assert "msg123" in message_ids
    end
  end

  describe "refresh_token/1" do
    test "handles missing environment variables" do
      user = create_user()
      account = create_account(user, %{refresh_token: "token"})

      # Test missing env vars (refresh_token nil case can't be tested due to schema validation)
      original_client_id = System.get_env("GOOGLE_CLIENT_ID")
      original_client_secret = System.get_env("GOOGLE_CLIENT_SECRET")

      System.delete_env("GOOGLE_CLIENT_ID")
      System.delete_env("GOOGLE_CLIENT_SECRET")

      try do
        result = Gmail.refresh_token(account)
        assert {:error, "Missing OAuth credentials"} = result
      after
        if original_client_id, do: System.put_env("GOOGLE_CLIENT_ID", original_client_id)

        if original_client_secret,
          do: System.put_env("GOOGLE_CLIENT_SECRET", original_client_secret)
      end
    end
  end

  describe "auth_headers edge cases" do
    test "returns empty list when account not found" do
      fake_id = Ecto.UUID.generate()

      # auth_headers is private, but we can test through get_message
      result = Gmail.get_message(fake_id, "msg123")
      assert {:error, "Authentication failed: no valid access token"} = result
    end

    test "handles expired token scenario" do
      user = create_user()
      # Create account with expired token - get_account_with_valid_token will try to refresh
      account =
        create_account(user, %{
          # Expired
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second),
          refresh_token: "valid_refresh_token"
        })

      # With invalid test credentials, refresh will fail
      result = Gmail.get_message(account.id, "msg123")
      assert {:error, _reason} = result
    end
  end

  describe "list_history/2 edge cases" do
    test "handles empty history array" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: "100",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "history") ->
              mock_json(%{"history" => []})

            String.contains?(url, "profile") ->
              mock_json(%{"historyId" => "101"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, message_ids, _history_id} = result
      assert message_ids == []
    end
  end
end
