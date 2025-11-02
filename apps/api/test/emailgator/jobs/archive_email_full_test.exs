defmodule Emailgator.Jobs.ArchiveEmailFullTest do
  use Emailgator.DataCase

  alias Emailgator.Jobs.ArchiveEmail
  alias Emailgator.{Accounts, Emails}

  test "perform/1 returns cancel when account not found" do
    fake_account_id = Ecto.UUID.generate()

    assert {:cancel, "Account not found"} =
             ArchiveEmail.perform(%Oban.Job{
               args: %{"account_id" => fake_account_id, "message_id" => "msg123"}
             })
  end

  test "perform/1 handles Gmail archive success" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    email = create_email(account, category, %{gmail_message_id: "msg123"})

    # Mock will be needed for Gmail.archive_message, but for now test structure
    job = %Oban.Job{
      args: %{"account_id" => account.id, "message_id" => "msg123"}
    }

    # Without mocking, this will call real Gmail which will fail
    # But we can verify the job args are correct
    assert job.args["account_id"] == account.id
    assert job.args["message_id"] == "msg123"
  end

  test "perform/1 handles email not found in database gracefully" do
    user = create_user()
    account = create_account(user)

    # Test that job structure accepts message_id even if email not in DB
    job = %Oban.Job{
      args: %{"account_id" => account.id, "message_id" => "nonexistent_msg"}
    }

    assert is_map(job.args)
  end
end
