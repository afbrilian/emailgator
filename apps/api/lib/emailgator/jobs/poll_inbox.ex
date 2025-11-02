defmodule Emailgator.Jobs.PollInbox do
  @moduledoc """
  Polls a Gmail account for new messages.
  """
  use Oban.Worker, queue: :poll, max_attempts: 3
  alias Emailgator.{Accounts, Gmail, Jobs.ImportEmail}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id}}) do
    Logger.info("PollInbox: Starting poll for account #{account_id}")

    case Accounts.get_account(account_id) do
      nil ->
        Logger.error("PollInbox: Account #{account_id} not found")
        {:cancel, "Account not found"}

      account ->
        Logger.info(
          "PollInbox: Found account #{account.id} (email: #{account.email}), last_history_id: #{inspect(account.last_history_id)}"
        )

        case Gmail.list_new_message_ids(account) do
          {:ok, message_ids, new_history_id} ->
            Logger.info(
              "PollInbox: Gmail API returned #{length(message_ids)} new message(s), new_history_id: #{inspect(new_history_id)}"
            )

            if Enum.empty?(message_ids) do
              Logger.info("PollInbox: No new messages found")
            else
              Logger.info("PollInbox: Queuing import jobs for #{length(message_ids)} message(s)")
            end

            # Update history_id (always update, even if it's nil, to track the current state)
            case Accounts.update_account(account, %{last_history_id: new_history_id}) do
              {:ok, _updated_account} ->
                Logger.info(
                  "PollInbox: Updated account history_id from #{inspect(account.last_history_id)} to #{inspect(new_history_id)}"
                )

                # Verify the update persisted
                reloaded_account = Accounts.get_account(account_id)

                Logger.info(
                  "PollInbox: Verified account.last_history_id is now: #{inspect(reloaded_account.last_history_id)}"
                )

              {:error, reason} ->
                Logger.error("PollInbox: Failed to update history_id: #{inspect(reason)}")
            end

            # Queue import jobs for each message
            Enum.each(message_ids, fn message_id ->
              Logger.debug("PollInbox: Queuing ImportEmail job for message_id: #{message_id}")

              case %{account_id: account_id, message_id: message_id}
                   |> ImportEmail.new()
                   |> Oban.insert() do
                {:ok, job} ->
                  Logger.debug(
                    "PollInbox: Successfully queued ImportEmail job #{job.id} for message_id: #{message_id}"
                  )

                {:error, reason} ->
                  Logger.error(
                    "PollInbox: Failed to queue ImportEmail job for message_id #{message_id}: #{inspect(reason)}"
                  )
              end
            end)

            Logger.info(
              "PollInbox: Completed poll for account #{account_id}, found #{length(message_ids)} new message(s)"
            )

            :ok

          {:error, reason} ->
            Logger.error(
              "PollInbox: Gmail API error for account #{account_id}: #{inspect(reason)}"
            )

            # Handle rate limits with exponential backoff
            if String.contains?(inspect(reason), "429") do
              Logger.warning("PollInbox: Rate limited, snoozing for 5 minutes")
              {:snooze, 300}
            else
              {:error, reason}
            end
        end
    end
  end
end
