defmodule Emailgator.Jobs.ArchiveEmail do
  @moduledoc """
  Archives an email in Gmail after it's been imported.
  """
  use Oban.Worker, queue: :archive, max_attempts: 3
  alias Emailgator.{Accounts, Gmail, Emails}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id, "message_id" => message_id}}) do
    account = Accounts.get_account(account_id)

    if is_nil(account) do
      {:cancel, "Account not found"}
    else
      case Gmail.archive_message(account_id, message_id) do
        {:ok, :archived} ->
          # Update email record
          case Emails.get_email_by_gmail_id(account_id, message_id) do
            nil -> :ok
            email -> Emails.update_email(email, %{archived_at: DateTime.utc_now()})
          end

          :ok

        {:error, reason} ->
          if String.contains?(inspect(reason), "429") do
            {:snooze, 300}
          else
            {:error, reason}
          end
      end
    end
  end
end
