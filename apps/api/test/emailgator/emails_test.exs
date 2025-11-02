defmodule Emailgator.EmailsTest do
  use Emailgator.DataCase

  alias Emailgator.Emails

  describe "emails" do
    test "create_email/1 creates email with valid attributes" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      attrs = %{
        subject: "Test Email",
        from: "sender@example.com",
        snippet: "Test snippet",
        gmail_message_id: "gmail_unique_#{System.unique_integer([:positive])}",
        account_id: account.id,
        category_id: category.id
      }

      assert {:ok, email} = Emails.create_email(attrs)
      assert email.subject == "Test Email"
      assert email.account_id == account.id
      assert email.category_id == category.id
    end

    test "list_category_emails/1 returns emails for category" do
      user = create_user()
      account = create_account(user)
      category1 = create_category(user, %{name: "Category 1"})
      category2 = create_category(user, %{name: "Category 2"})

      email1 = create_email(account, category1, %{subject: "Email 1"})
      email2 = create_email(account, category1, %{subject: "Email 2"})
      _email3 = create_email(account, category2, %{subject: "Email 3"})

      emails = Emails.list_category_emails(category1.id)
      assert length(emails) == 2
      assert email1.id in Enum.map(emails, & &1.id)
      assert email2.id in Enum.map(emails, & &1.id)
    end

    test "get_email_by_gmail_id/2 returns email when exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category, %{gmail_message_id: "gmail_123"})

      found = Emails.get_email_by_gmail_id(account.id, "gmail_123")
      assert found.id == email.id
    end

    test "get_email_by_gmail_id/2 returns nil when doesn't exist" do
      user = create_user()
      account = create_account(user)
      assert Emails.get_email_by_gmail_id(account.id, "nonexistent") == nil
    end

    test "delete_emails/1 deletes multiple emails" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      email1 = create_email(account, category)
      email2 = create_email(account, category)
      email3 = create_email(account, category)

      {count, _} = Emails.delete_emails([email1.id, email2.id])
      assert count == 2
      assert Emails.get_email(email1.id) == nil
      assert Emails.get_email(email2.id) == nil
      assert Emails.get_email(email3.id) != nil
    end
  end
end
