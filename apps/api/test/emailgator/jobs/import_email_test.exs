defmodule Emailgator.Jobs.ImportEmailTest do
  use Emailgator.DataCase

  alias Emailgator.Jobs.ImportEmail

  test "perform/1 returns cancel when account not found" do
    fake_account_id = Ecto.UUID.generate()

    assert {:cancel, "Account not found"} =
             ImportEmail.perform(%Oban.Job{
               args: %{"account_id" => fake_account_id, "message_id" => "msg123"}
             })
  end

  test "perform/1 skips already imported emails" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    message_id = "gmail_msg_#{System.unique_integer([:positive])}"

    # Create email with this gmail_message_id
    create_email(account, category, %{gmail_message_id: message_id})

    assert :ok =
             ImportEmail.perform(%Oban.Job{
               args: %{"account_id" => account.id, "message_id" => message_id}
             })
  end
end
