defmodule Emailgator.Jobs.ArchiveEmailTest do
  use Emailgator.DataCase

  alias Emailgator.Jobs.ArchiveEmail

  test "perform/1 returns cancel when account not found" do
    fake_account_id = Ecto.UUID.generate()

    assert {:cancel, "Account not found"} =
             ArchiveEmail.perform(%Oban.Job{
               args: %{"account_id" => fake_account_id, "message_id" => "msg123"}
             })
  end
end
