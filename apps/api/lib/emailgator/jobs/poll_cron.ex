defmodule Emailgator.Jobs.PollCron do
  @moduledoc """
  Oban cron job that triggers polling for all active accounts.
  Runs every 2 minutes.
  """
  use Oban.Worker, queue: :poll, max_attempts: 1

  @impl Oban.Worker
  def perform(_job) do
    alias Emailgator.Accounts
    alias Emailgator.Jobs.PollInbox

    require Logger

    Logger.info("PollCron: Starting scheduled poll for all active accounts")

    accounts = Accounts.list_active_accounts()
    Logger.info("PollCron: Found #{length(accounts)} active account(s)")

    accounts
    |> Enum.each(fn account ->
      Logger.info("PollCron: Queuing PollInbox job for account #{account.id}")
      %{account_id: account.id}
      |> PollInbox.new()
      |> Oban.insert()
    end)

    Logger.info("PollCron: Completed scheduled poll")
    :ok
  end
end
