defmodule EmailgatorWeb.Schema.Resolvers.AccountTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  import Mox

  alias EmailgatorWeb.Schema.Resolvers.Account

  setup :verify_on_exit!

  describe "list/3" do
    test "returns accounts for authenticated user" do
      user = create_user()
      account1 = create_account(user, %{email: "account1@example.com"})
      account2 = create_account(user, %{email: "account2@example.com"})
      context = build_context(user)

      assert {:ok, accounts} = Account.list(nil, %{}, context)
      assert length(accounts) == 2
      assert account1.id in Enum.map(accounts, & &1.id)
      assert account2.id in Enum.map(accounts, & &1.id)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Account.list(nil, %{}, %{})
    end
  end

  describe "trigger_poll/3" do
    test "queues poll job for all user accounts when account_id is nil" do
      user = create_user()
      account = create_account(user, %{refresh_token: "token_123"})
      context = build_context(user)

      assert {:ok, true} = Account.trigger_poll(nil, %{}, context)

      # Verify job was queued (check Oban.Job table)
      import Ecto.Query
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) == 1
      assert hd(jobs).args["account_id"] == account.id
    end

    test "queues poll job for specific account" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      assert {:ok, true} = Account.trigger_poll(nil, %{account_id: account.id}, context)

      import Ecto.Query
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
      assert length(jobs) == 1
      assert hd(jobs).args["account_id"] == account.id
    end

    test "returns error when account not found" do
      user = create_user()
      context = build_context(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, "Account not found"} =
               Account.trigger_poll(nil, %{account_id: fake_id}, context)
    end

    test "returns error when account belongs to different user" do
      user1 = create_user()
      user2 = create_user()
      account = create_account(user1)
      context = build_context(user2)

      assert {:error, "Account does not belong to user"} =
               Account.trigger_poll(nil, %{account_id: account.id}, context)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Account.trigger_poll(nil, %{}, %{})
    end
  end

  describe "polling_status/3" do
    test "returns false when no polling jobs exist" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      assert {:ok, false} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns true when polling job exists" do
      user = create_user()
      account = create_account(user)
      context = build_context(user)

      # Create a poll job
      %{account_id: account.id}
      |> Emailgator.Jobs.PollInbox.new()
      |> Oban.insert()

      assert {:ok, true} = Account.polling_status(nil, %{account_id: account.id}, context)
    end

    test "returns false when user has no accounts" do
      user = create_user()
      context = build_context(user)

      assert {:ok, false} = Account.polling_status(nil, %{}, context)
    end
  end
end
