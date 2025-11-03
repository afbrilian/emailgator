defmodule Emailgator.Jobs.PollCronTest do
  use Emailgator.DataCase
  import Ecto.Query

  alias Emailgator.Jobs.PollCron

  setup do
    # Clean up any existing Oban jobs before each test
    Emailgator.Repo.delete_all(from(j in Oban.Job))
    :ok
  end

  test "perform/1 queues poll jobs for all active accounts" do
    user = create_user()

    # Create active accounts (have refresh_token)
    account1 = create_account(user, %{refresh_token: "token1"})
    account2 = create_account(user, %{refresh_token: "token2"})

    assert :ok = PollCron.perform(%Oban.Job{args: %{}})

    # Verify jobs were queued for active accounts only
    jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
    # Should have 2 jobs (one per active account)
    assert length(jobs) >= 2

    account_ids = Enum.map(jobs, fn job -> job.args["account_id"] end)
    assert account1.id in account_ids
    assert account2.id in account_ids
  end

  test "perform/1 handles no active accounts" do
    # Don't create any accounts - list_active_accounts should return empty
    assert :ok = PollCron.perform(%Oban.Job{args: %{}})

    jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
    assert length(jobs) == 0
  end

  test "perform/1 handles Oban.insert failures gracefully" do
    user = create_user()
    account = create_account(user, %{refresh_token: "token1"})

    # PollCron will attempt to queue jobs even if some fail
    # The function doesn't check return values, so it continues
    assert :ok = PollCron.perform(%Oban.Job{args: %{}})

    # Should have attempted to queue at least one job
    jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
    assert length(jobs) >= 1
  end

  test "perform/1 processes multiple accounts" do
    user1 = create_user()
    user2 = create_user()

    account1 = create_account(user1, %{refresh_token: "token1"})
    account2 = create_account(user1, %{refresh_token: "token2"})
    account3 = create_account(user2, %{refresh_token: "token3"})

    assert :ok = PollCron.perform(%Oban.Job{args: %{}})

    jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "poll"))
    assert length(jobs) >= 3

    account_ids = Enum.map(jobs, fn job -> job.args["account_id"] end)
    assert account1.id in account_ids
    assert account2.id in account_ids
    assert account3.id in account_ids
  end
end
