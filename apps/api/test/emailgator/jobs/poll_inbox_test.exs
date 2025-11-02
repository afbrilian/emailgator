defmodule Emailgator.Jobs.PollInboxTest do
  use Emailgator.DataCase

  alias Emailgator.Jobs.PollInbox

  test "perform/1 returns cancel when account not found" do
    fake_account_id = Ecto.UUID.generate()

    assert {:cancel, "Account not found"} =
             PollInbox.perform(%Oban.Job{
               args: %{"account_id" => fake_account_id}
             })
  end

  # Note: Full integration tests for PollInbox would require:
  # - Valid Gmail OAuth tokens
  # - Real Gmail account with messages
  # - Network access to Gmail API
end
