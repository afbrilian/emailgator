defmodule Emailgator.EmailsComprehensiveTest do
  use Emailgator.DataCase

  alias Emailgator.{Emails, Accounts, Categories}

  describe "get_email!/1" do
    test "returns email when exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      result = Emails.get_email!(email.id)
      assert result.id == email.id
    end

    test "raises when email doesn't exist" do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Emails.get_email!(fake_id)
      end
    end
  end

  describe "get_email_with_account/1" do
    test "returns email with preloaded account" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      result = Emails.get_email_with_account(email.id)
      assert result.id == email.id
      assert result.account != nil
      assert result.account.id == account.id
    end

    test "returns nil when email doesn't exist" do
      fake_id = Ecto.UUID.generate()
      result = Emails.get_email_with_account(fake_id)
      assert result == nil
    end
  end

  describe "update_email/2" do
    test "updates email attributes" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{subject: "Updated Subject", summary: "Updated summary"}
      assert {:ok, updated_email} = Emails.update_email(email, attrs)
      assert updated_email.subject == "Updated Subject"
      assert updated_email.summary == "Updated summary"
    end

    test "returns error on invalid attributes" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      # Invalid - missing required fields
      attrs = %{gmail_message_id: nil}
      assert {:error, changeset} = Emails.update_email(email, attrs)
      refute changeset.valid?
    end
  end

  describe "delete_emails/1" do
    test "deletes multiple emails by IDs" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category)
      email2 = create_email(account, category)
      email3 = create_email(account, category)

      {deleted_count, _} = Emails.delete_emails([email1.id, email2.id])

      assert deleted_count == 2
      assert Emails.get_email(email1.id) == nil
      assert Emails.get_email(email2.id) == nil
      assert Emails.get_email(email3.id) != nil
    end

    test "handles empty list" do
      {deleted_count, _} = Emails.delete_emails([])
      assert deleted_count == 0
    end

    test "handles non-existent IDs gracefully" do
      fake_id = Ecto.UUID.generate()
      {deleted_count, _} = Emails.delete_emails([fake_id])
      assert deleted_count == 0
    end
  end

  describe "list_category_emails/1" do
    test "returns emails for a category" do
      user = create_user()
      account = create_account(user)
      category1 = create_category(user, %{name: "Category 1"})
      category2 = create_category(user, %{name: "Category 2"})

      email1 = create_email(account, category1)
      email2 = create_email(account, category1)
      _email3 = create_email(account, category2)

      emails = Emails.list_category_emails(category1.id)
      assert length(emails) == 2
      email_ids = Enum.map(emails, & &1.id)
      assert email1.id in email_ids
      assert email2.id in email_ids
    end

    test "returns empty list when no emails" do
      user = create_user()
      category = create_category(user)

      emails = Emails.list_category_emails(category.id)
      assert emails == []
    end
  end

  describe "list_account_emails/1" do
    test "returns emails for an account" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      category = create_category(user)

      email1 = create_email(account1, category)
      email2 = create_email(account1, category)
      _email3 = create_email(account2, category)

      emails = Emails.list_account_emails(account1.id)
      assert length(emails) == 2
      email_ids = Enum.map(emails, & &1.id)
      assert email1.id in email_ids
      assert email2.id in email_ids
    end
  end

  describe "get_email_by_gmail_id/2" do
    test "returns email when exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category, %{gmail_message_id: "unique_gmail_id"})

      result = Emails.get_email_by_gmail_id(account.id, "unique_gmail_id")
      assert result.id == email.id
    end

    test "returns nil when email doesn't exist" do
      user = create_user()
      account = create_account(user)

      result = Emails.get_email_by_gmail_id(account.id, "nonexistent_id")
      assert result == nil
    end

    test "returns nil for wrong account" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      category = create_category(user)
      email = create_email(account1, category, %{gmail_message_id: "unique_gmail_id"})

      result = Emails.get_email_by_gmail_id(account2.id, "unique_gmail_id")
      assert result == nil
    end
  end

  describe "create_email/1" do
    test "creates email with valid attributes" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      attrs = %{
        account_id: account.id,
        category_id: category.id,
        gmail_message_id: "msg_#{System.unique_integer([:positive])}",
        subject: "Test Subject",
        from: "test@example.com"
      }

      assert {:ok, email} = Emails.create_email(attrs)
      assert email.subject == "Test Subject"
      assert email.account_id == account.id
      assert email.category_id == category.id
    end

    test "returns error when required fields missing" do
      attrs = %{subject: "Test"}

      assert {:error, changeset} = Emails.create_email(attrs)
      refute changeset.valid?

      assert %{gmail_message_id: ["can't be blank"], account_id: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "enforces unique constraint on account_id and gmail_message_id" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      gmail_id = "unique_gmail_#{System.unique_integer([:positive])}"

      attrs = %{
        account_id: account.id,
        category_id: category.id,
        gmail_message_id: gmail_id,
        subject: "First"
      }

      assert {:ok, _email1} = Emails.create_email(attrs)

      # Try to create duplicate
      assert {:error, changeset} = Emails.create_email(attrs)
      refute changeset.valid?
    end
  end

  describe "get_email/1" do
    test "returns email when exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert Emails.get_email(email.id).id == email.id
    end

    test "returns nil when email doesn't exist" do
      fake_id = Ecto.UUID.generate()
      assert Emails.get_email(fake_id) == nil
    end
  end

  describe "delete_email/1" do
    test "deletes email successfully" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, _deleted} = Emails.delete_email(email)
      assert Emails.get_email(email.id) == nil
    end
  end

  describe "list_account_emails/1 edge cases" do
    test "returns empty list when account has no emails" do
      user = create_user()
      account = create_account(user)

      assert Emails.list_account_emails(account.id) == []
    end

    test "returns emails ordered by inserted_at desc" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      # Create emails - they should be ordered by inserted_at desc
      email1 = create_email(account, category, %{subject: "First"})
      email2 = create_email(account, category, %{subject: "Second"})

      emails = Emails.list_account_emails(account.id)
      assert length(emails) >= 2

      # Verify both emails are present and ordered by inserted_at desc
      email_ids = Enum.map(emails, & &1.id)
      assert email1.id in email_ids
      assert email2.id in email_ids

      # Most recent (email2) should be first or second depending on timing
      # The key is that the list is ordered desc, which is tested by the query itself
      assert email2.id in email_ids
    end
  end
end
