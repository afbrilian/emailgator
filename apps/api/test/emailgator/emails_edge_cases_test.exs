defmodule Emailgator.EmailsEdgeCasesTest do
  use Emailgator.DataCase

  alias Emailgator.Emails

  describe "edge cases" do
    test "create_email with minimal required fields" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      attrs = %{
        account_id: account.id,
        category_id: category.id,
        gmail_message_id: "minimal_#{System.unique_integer([:positive])}"
      }

      assert {:ok, email} = Emails.create_email(attrs)
      assert email.account_id == account.id
      assert email.category_id == category.id
      assert email.gmail_message_id == attrs.gmail_message_id
    end

    test "create_email with all optional fields" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      attrs = %{
        account_id: account.id,
        category_id: category.id,
        gmail_message_id: "full_#{System.unique_integer([:positive])}",
        subject: "Full Email",
        from: "sender@example.com",
        snippet: "Email snippet",
        summary: "Email summary",
        body_text: "Email body text",
        body_html: "<p>Email body HTML</p>",
        unsubscribe_urls: ["https://example.com/unsub1", "https://example.com/unsub2"],
        archived_at: DateTime.utc_now()
      }

      assert {:ok, email} = Emails.create_email(attrs)
      assert email.subject == "Full Email"
      assert email.from == "sender@example.com"
      assert email.summary == "Email summary"
      assert length(email.unsubscribe_urls) == 2
      assert email.archived_at != nil
    end

    test "update_email with partial fields" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{summary: "Updated summary only"}
      assert {:ok, updated} = Emails.update_email(email, attrs)
      assert updated.summary == "Updated summary only"
      assert updated.subject == email.subject
    end

    test "update_email with archived_at" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      archived_at = DateTime.utc_now() |> DateTime.truncate(:second)
      attrs = %{archived_at: archived_at}
      assert {:ok, updated} = Emails.update_email(email, attrs)
      # Compare truncated to avoid microsecond precision issues
      assert DateTime.truncate(updated.archived_at, :second) == archived_at
    end

    test "list_category_emails returns empty when category has no emails" do
      user = create_user()
      category = create_category(user)

      assert Emails.list_category_emails(category.id) == []
    end

    test "list_account_emails returns empty when account has no emails" do
      user = create_user()
      account = create_account(user)

      assert Emails.list_account_emails(account.id) == []
    end

    test "get_email_with_account preloads account relationship" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      result = Emails.get_email_with_account(email.id)
      assert result != nil
      assert result.account != nil
      assert result.account.id == account.id
      assert result.account.email == account.email
    end

    test "get_email_with_account returns nil for non-existent email" do
      fake_id = Ecto.UUID.generate()
      assert Emails.get_email_with_account(fake_id) == nil
    end

    test "delete_emails handles mixed existent and non-existent IDs" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category)
      email2 = create_email(account, category)
      fake_id = Ecto.UUID.generate()

      {deleted_count, _} = Emails.delete_emails([email1.id, fake_id, email2.id])

      assert deleted_count == 2
      assert Emails.get_email(email1.id) == nil
      assert Emails.get_email(email2.id) == nil
    end

    test "delete_emails with duplicate IDs" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      {deleted_count, _} = Emails.delete_emails([email.id, email.id, email.id])

      assert deleted_count == 1
      assert Emails.get_email(email.id) == nil
    end

    test "get_email_by_gmail_id with same message_id but different account" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      category = create_category(user)

      message_id = "same_message_#{System.unique_integer([:positive])}"
      email1 = create_email(account1, category, %{gmail_message_id: message_id})
      _email2 = create_email(account2, category, %{gmail_message_id: message_id})

      result1 = Emails.get_email_by_gmail_id(account1.id, message_id)
      result2 = Emails.get_email_by_gmail_id(account2.id, message_id)

      assert result1.id == email1.id
      assert result2 != nil
      assert result1.id != result2.id
    end

    test "create_email enforces unique constraint across accounts" do
      user = create_user()
      account1 = create_account(user)
      account2 = create_account(user)
      category = create_category(user)

      message_id = "unique_#{System.unique_integer([:positive])}"

      assert {:ok, _email1} =
               Emails.create_email(%{
                 account_id: account1.id,
                 category_id: category.id,
                 gmail_message_id: message_id
               })

      assert {:ok, _email2} =
               Emails.create_email(%{
                 account_id: account2.id,
                 category_id: category.id,
                 gmail_message_id: message_id
               })

      # Same account and message_id should fail
      assert {:error, changeset} =
               Emails.create_email(%{
                 account_id: account1.id,
                 category_id: category.id,
                 gmail_message_id: message_id
               })

      refute changeset.valid?
    end
  end
end
