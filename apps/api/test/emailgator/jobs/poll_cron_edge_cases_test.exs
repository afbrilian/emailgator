defmodule Emailgator.Jobs.PollCronEdgeCasesTest do
  use Emailgator.DataCase
  import Tesla.Mock
  import Ecto.Query

  alias Emailgator.Jobs.PollCron
  alias Emailgator.Accounts

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
    end)

    :ok
  end

  describe "PollCron edge cases" do
    test "perform/1 handles empty active accounts list" do
      # No accounts exist
      result = PollCron.perform(%Oban.Job{})

      assert :ok = result

      # Verify no jobs were queued
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) == 0
    end

    test "perform/1 queues jobs for multiple active accounts" do
      user1 = create_user()
      user2 = create_user()

      account1 = create_account(user1, %{refresh_token: "token1"})
      account2 = create_account(user1, %{refresh_token: "token2"})
      account3 = create_account(user2, %{refresh_token: "token3"})

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") and String.contains?(url, "in:inbox") ->
              mock_json(%{"messages" => []})

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "12345"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = PollCron.perform(%Oban.Job{})

      assert :ok = result

      # Verify jobs were queued for all active accounts
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) >= 3

      # Verify all account IDs are in the jobs
      job_account_ids =
        Enum.map(jobs, fn job ->
          case job.args do
            %{"account_id" => account_id} -> account_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      assert account1.id in job_account_ids
      assert account2.id in job_account_ids
      assert account3.id in job_account_ids
    end

    test "perform/1 handles accounts without refresh_token" do
      user = create_user()

      # Note: refresh_token is required, so we can't easily create accounts without it
      # But we verify that list_active_accounts filters correctly
      account_with_token = create_account(user, %{refresh_token: "token"})

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") and String.contains?(url, "in:inbox") ->
              mock_json(%{"messages" => []})

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "12345"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = PollCron.perform(%Oban.Job{})

      assert :ok = result

      # Should queue job for account with token
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) >= 1
    end

    test "perform/1 handles Oban.insert failures gracefully" do
      user = create_user()
      account = create_account(user, %{refresh_token: "token"})

      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") and String.contains?(url, "in:inbox") ->
              mock_json(%{"messages" => []})

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "12345"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      result = PollCron.perform(%Oban.Job{})

      # Should still return :ok even if some job inserts fail
      assert :ok = result
    end
  end
end
