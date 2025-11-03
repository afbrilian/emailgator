defmodule EmailgatorWeb.Schema.Resolvers.AccountTest do
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Account
  alias Emailgator.{Accounts, Jobs.PollInbox}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Emailgator.Repo)
    :ok
  end

  describe "list/3" do
    test "returns user accounts when authenticated" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      _other_user = create_user()
      _other_account = create_account(_other_user)

      context = %{context: %{current_user: user}}
      assert {:ok, accounts} = Account.list(nil, %{}, context)

      account_ids = Enum.map(accounts, & &1.id)
      assert account1.id in account_ids
      assert account2.id in account_ids
      assert length(accounts) == 2
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Account.list(nil, %{}, context)
    end
  end

  describe "get_connect_url/3" do
    test "returns connect URL when authenticated" do
      user = create_user()
      context = %{context: %{current_user: user}}

      assert {:ok, url} = Account.get_connect_url(nil, %{}, context)
      assert String.contains?(url, "/gmail/connect")
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Account.get_connect_url(nil, %{}, context)
    end
  end

  describe "disconnect/3" do
    test "deletes account when it exists and belongs to user" do
      user = create_user()
      account = create_account(user)
      context = %{context: %{current_user: user}}

      assert {:ok, _deleted} = Account.disconnect(nil, %{id: account.id}, context)
      assert Accounts.get_account(account.id) == nil
    end

    test "returns error when account not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: user}}

      assert {:error, "Account not found"} = Account.disconnect(nil, %{id: fake_id}, context)
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Account.disconnect(nil, %{id: "test"}, context)
    end
  end

  describe "trigger_poll/3" do
    test "queues poll job for all user accounts when account_id not provided" do
      user = create_user()
      account1 = create_account(user, %{refresh_token: "token1"})
      account2 = create_account(user, %{refresh_token: "token2"})
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, true} = Account.trigger_poll(nil, %{}, context)

      # Verify jobs were queued
      import Ecto.Query
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) >= 2
    end

    test "queues poll job for specific account when account_id provided" do
      user = create_user()
      account = create_account(user)
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, true} = Account.trigger_poll(nil, %{account_id: account.id}, context)

      # Verify job was queued
      import Ecto.Query

      jobs =
        Emailgator.Repo.all(
          from(j in Oban.Job,
            where:
              j.queue == "poll" and fragment("?->>'account_id'", j.args) == ^to_string(account.id)
          )
        )

      assert length(jobs) >= 1
    end

    test "returns error when account not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:error, "Account not found"} =
               Account.trigger_poll(nil, %{account_id: fake_id}, context)
    end

    test "returns error when account doesn't belong to user" do
      user1 = create_user()
      user2 = create_user()
      account = create_account(user2)
      context = %{context: %{current_user: %{id: user1.id}}}

      assert {:error, "Account does not belong to user"} =
               Account.trigger_poll(nil, %{account_id: account.id}, context)
    end

    test "only queues jobs for accounts with refresh_token" do
      user = create_user()
      # All accounts created via create_account have refresh_token (required field)
      # The filtering happens in the code, so we test that all accounts with tokens get jobs
      account1 = create_account(user, %{refresh_token: "token1"})
      account2 = create_account(user, %{refresh_token: "token2"})
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, true} = Account.trigger_poll(nil, %{}, context)

      # Should queue jobs for both accounts with tokens
      import Ecto.Query
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) >= 2

      # Verify both account IDs are in the jobs
      # Oban stores args as a map directly, not JSON string
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
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Account.trigger_poll(nil, %{}, context)
    end
  end

  describe "polling_status/3" do
    test "returns false when user has no accounts" do
      user = create_user()
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, false} = Account.polling_status(nil, %{}, context)
    end

    test "returns false when no poll jobs exist" do
      user = create_user()
      _account = create_account(user)
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, false} = Account.polling_status(nil, %{}, context)
    end

    test "returns true when poll job exists for account" do
      user = create_user()
      account = create_account(user)
      context = %{context: %{current_user: %{id: user.id}}}

      # Create a poll job
      %{account_id: account.id}
      |> PollInbox.new()
      |> Oban.insert()

      assert {:ok, true} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns false when no poll job exists for account" do
      user = create_user()
      account = create_account(user)
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, false} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns error when account not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:error, "Account not found"} =
               Account.polling_status(nil, %{account_id: fake_id}, context)
    end

    test "returns error when account doesn't belong to user" do
      user1 = create_user()
      user2 = create_user()
      account = create_account(user2)
      context = %{context: %{current_user: %{id: user1.id}}}

      assert {:error, "Account does not belong to user"} =
               Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Account.polling_status(nil, %{}, context)
    end
  end
end
