defmodule Emailgator.EmailsFullTest do
  use Emailgator.DataCase

  alias Emailgator.Emails

  describe "list_account_emails/1" do
    test "returns emails for account" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      category = create_category(user)

      email1 = create_email(account1, category, %{subject: "Email 1"})
      email2 = create_email(account1, category, %{subject: "Email 2"})
      _email3 = create_email(account2, category, %{subject: "Email 3"})

      emails = Emails.list_account_emails(account1.id)
      assert length(emails) == 2
      assert email1.id in Enum.map(emails, & &1.id)
      assert email2.id in Enum.map(emails, & &1.id)
    end
  end

  describe "get_email_with_account/1" do
    test "returns email with preloaded account" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      found = Emails.get_email_with_account(email.id)
      assert found.id == email.id
      assert found.account.id == account.id
    end

    test "returns nil when not found" do
      fake_id = Ecto.UUID.generate()
      assert Emails.get_email_with_account(fake_id) == nil
    end
  end

  describe "update_email/2" do
    test "updates email attributes" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category, %{subject: "Old Subject"})

      assert {:ok, updated} = Emails.update_email(email, %{subject: "New Subject"})
      assert updated.subject == "New Subject"
    end
  end

  describe "delete_email/1" do
    test "deletes email" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, _} = Emails.delete_email(email)
      assert Emails.get_email(email.id) == nil
    end
  end
end
