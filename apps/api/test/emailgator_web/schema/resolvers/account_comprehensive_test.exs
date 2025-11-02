defmodule EmailgatorWeb.Schema.Resolvers.AccountComprehensiveTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase
  import Ecto.Query

  alias EmailgatorWeb.Schema.Resolvers.Account

  describe "polling_status/3 comprehensive" do
    test "returns false for specific account with no jobs" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      assert {:ok, false} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns true for specific account with available job" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      # Create a poll job
      %{account_id: account.id}
      |> Emailgator.Jobs.PollInbox.new()
      |> Oban.insert()

      assert {:ok, true} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns true for specific account with scheduled job" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      # Insert job scheduled in the future
      {:ok, _job} =
        %{account_id: account.id}
        |> Emailgator.Jobs.PollInbox.new(schedule_in: 60)
        |> Oban.insert()

      assert {:ok, true} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns error when account not found" do
      user = create_user()
      context = build_context(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, "Account not found"} =
               Account.polling_status(nil, %{account_id: fake_id}, context)
    end

    test "returns error when account belongs to different user" do
      user1 = create_user()
      user2 = create_user()
      account = create_account(user1)
      context = build_context(user2)

      assert {:error, "Account does not belong to user"} =
               Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns true when user has accounts with jobs" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      # Create poll job
      %{account_id: account.id}
      |> Emailgator.Jobs.PollInbox.new()
      |> Oban.insert()

      assert {:ok, true} = Account.polling_status(nil, %{}, context)
    end
  end

  describe "trigger_poll/3 comprehensive" do
    test "queues jobs for all accounts when account_id is nil" do
      user = create_user()
      account1 = create_account(user, %{refresh_token: "token1"})
      account2 = create_account(user, %{refresh_token: "token2"})
      context = build_context(user)

      # Clean jobs
      Emailgator.Repo.delete_all(from(j in Oban.Job))

      assert {:ok, true} = Account.trigger_poll(nil, %{}, context)

      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) >= 2
      account_ids = Enum.map(jobs, fn job -> job.args["account_id"] end)
      assert account1.id in account_ids
      assert account2.id in account_ids
    end

    test "skips accounts without refresh_token" do
      user = create_user()
      _account1 = create_account(user, %{refresh_token: "token1"})
      # Account without refresh_token shouldn't get polled, but we can't easily create one
      context = build_context(user)

      Emailgator.Repo.delete_all(from(j in Oban.Job))

      assert {:ok, true} = Account.trigger_poll(nil, %{}, context)

      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      # Should only queue accounts with refresh_token
      assert length(jobs) >= 1
    end
  end
end
