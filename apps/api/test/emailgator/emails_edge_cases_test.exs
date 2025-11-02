defmodule Emailgator.EmailsEdgeCasesTest do
  use Emailgator.DataCase

  alias Emailgator.Emails

  describe "get_email!/1" do
    test "returns email when found" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      found = Emails.get_email!(email.id)
      assert found.id == email.id
    end

    test "raises when not found" do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Emails.get_email!(fake_id)
      end
    end
  end

  describe "get_email_by_gmail_id/2 edge cases" do
    test "returns nil for different account" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      category = create_category(user)
      email = create_email(account1, category)

      assert Emails.get_email_by_gmail_id(account2.id, email.gmail_message_id) == nil
    end
  end
end
