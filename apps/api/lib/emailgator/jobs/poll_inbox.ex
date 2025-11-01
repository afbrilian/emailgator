defmodule Emailgator.Jobs.PollInbox do
  @moduledoc """
  Polls a Gmail account for new messages.
  """
  use Oban.Worker, queue: :poll, max_attempts: 3
  alias Emailgator.{Accounts, Gmail, Jobs.ImportEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id}}) do
    case Accounts.get_account(account_id) do
      nil ->
        {:cancel, "Account not found"}

      account ->
        case Gmail.list_new_message_ids(account) do
          {:ok, message_ids, new_history_id} ->
            # Update history_id
            Accounts.update_account(account, %{last_history_id: new_history_id})

            # Queue import jobs for each message
            Enum.each(message_ids, fn message_id ->
              %{account_id: account_id, message_id: message_id}
              |> ImportEmail.new()
              |> Oban.insert()
            end)

            :ok

          {:error, reason} ->
            # Handle rate limits with exponential backoff
            if String.contains?(inspect(reason), "429") do
              # Retry in 5 minutes
              {:snooze, 300}
            else
              {:error, reason}
            end
        end
    end
  end
end
