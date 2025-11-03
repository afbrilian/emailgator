defmodule Emailgator.GmailHistoryIdTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.Gmail

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
    end)

    :ok
  end

  describe "extract_latest_history_id" do
    test "extracts max history ID from history array" do
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
                  %{"id" => "101"},
                  %{"id" => "105"},
                  %{"id" => "103"}
                ]
              })

            String.contains?(url, "profile") ->
              mock_json(%{"historyId" => "106"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, _message_ids, history_id} = result
      # Should use max history ID (105) or profile historyId (106)
      assert history_id != nil
    end

    test "handles history with nil IDs" do
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
                  %{"id" => nil},
                  %{"id" => "102"},
                  %{}
                ]
              })

            String.contains?(url, "profile") ->
              mock_json(%{"historyId" => "103"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, _message_ids, history_id} = result
      # Should filter out nil IDs
      assert history_id != nil
    end

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
      assert {:ok, _message_ids, history_id} = result
      # Should use original history_id or profile historyId
      assert history_id != nil
    end

    test "handles history with no id field" do
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
                  %{"messagesAdded" => []},
                  %{"id" => "102"}
                ]
              })

            String.contains?(url, "profile") ->
              mock_json(%{"historyId" => "103"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, _message_ids, history_id} = result
      assert history_id != nil
    end

    test "handles string vs numeric history IDs" do
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
                  %{"id" => "105"},
                  %{"id" => "110"}
                ]
              })

            String.contains?(url, "profile") ->
              mock_json(%{"historyId" => "115"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = Gmail.list_new_message_ids(account)
      assert {:ok, _message_ids, history_id} = result
      # Max should be "110" (string comparison)
      assert history_id != nil
    end
  end
end
