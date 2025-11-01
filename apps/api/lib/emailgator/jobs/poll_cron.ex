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

    Accounts.list_active_accounts()
    |> Enum.each(fn account ->
      %{account_id: account.id}
      |> PollInbox.new()
      |> Oban.insert()
    end)

    :ok
  end
end
