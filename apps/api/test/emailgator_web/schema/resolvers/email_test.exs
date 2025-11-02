defmodule EmailgatorWeb.Schema.Resolvers.EmailTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Email

  describe "list_by_category/3" do
    test "returns emails for category when authenticated" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category, %{subject: "Email 1"})
      email2 = create_email(account, category, %{subject: "Email 2"})
      context = build_context(user)

      assert {:ok, emails} = Email.list_by_category(nil, %{category_id: category.id}, context)
      assert length(emails) == 2
      assert email1.id in Enum.map(emails, & &1.id)
      assert email2.id in Enum.map(emails, & &1.id)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Email.list_by_category(nil, %{}, %{})
    end
  end

  describe "get_email/3" do
    test "returns email when belongs to user" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)
      context = build_context(user)

      assert {:ok, found_email} = Email.get_email(nil, %{id: email.id}, context)
      assert found_email.id == email.id
    end

    test "returns error when email not found" do
      user = create_user()
      context = build_context(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, "Email not found"} = Email.get_email(nil, %{id: fake_id}, context)
    end

    test "returns error when email belongs to different user" do
      user1 = create_user()
      user2 = create_user()
      account = create_account(user1)
      category = create_category(user1)
      email = create_email(account, category)
      context = build_context(user2)

      assert {:error, "Email not found"} = Email.get_email(nil, %{id: email.id}, context)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Email.get_email(nil, %{}, %{})
    end
  end

  describe "bulk_delete/3" do
    test "deletes emails for authenticated user" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category)
      email2 = create_email(account, category)
      email3 = create_email(account, category)
      context = build_context(user)

      assert {:ok, deleted_ids} =
               Email.bulk_delete(nil, %{email_ids: [email1.id, email2.id]}, context)

      assert length(deleted_ids) == 2
      assert email1.id in deleted_ids
      assert email2.id in deleted_ids
      assert Emailgator.Emails.get_email(email1.id) == nil
      assert Emailgator.Emails.get_email(email2.id) == nil
      assert Emailgator.Emails.get_email(email3.id) != nil
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Email.bulk_delete(nil, %{}, %{})
    end
  end

  describe "bulk_unsubscribe/3" do
    test "queues unsubscribe jobs for authenticated user" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category)
      email2 = create_email(account, category)
      context = build_context(user)

      assert {:ok, results} =
               Email.bulk_unsubscribe(nil, %{email_ids: [email1.id, email2.id]}, context)

      assert length(results) == 2
      assert Enum.all?(results, &(&1.success == true))

      # Verify jobs were queued
      import Ecto.Query
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "unsubscribe"))
      assert length(jobs) == 2
    end

    test "returns error for emails not belonging to user" do
      user1 = create_user()
      user2 = create_user()
      account1 = create_account(user1)
      account2 = create_account(user2)
      category1 = create_category(user1)
      category2 = create_category(user2)
      email1 = create_email(account1, category1)
      email2 = create_email(account2, category2)
      context = build_context(user1)

      assert {:ok, results} =
               Email.bulk_unsubscribe(nil, %{email_ids: [email1.id, email2.id]}, context)

      assert length(results) == 2
      # email1 should succeed, email2 should fail
      assert Enum.any?(results, fn r -> r.email_id == email1.id and r.success == true end)
      assert Enum.any?(results, fn r -> r.email_id == email2.id and r.success == false end)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Email.bulk_unsubscribe(nil, %{}, %{})
    end
  end

  describe "is_unsubscribed/3" do
    test "returns false when no unsubscribe attempts" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, false} = Email.is_unsubscribed(email, %{}, %{})
    end

    test "returns true when successful unsubscribe exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      # Create a successful unsubscribe attempt
      {:ok, _attempt} =
        Emailgator.Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "playwright",
          url: "https://example.com/unsubscribe",
          status: "success"
        })

      assert {:ok, true} = Email.is_unsubscribed(email, %{}, %{})
    end
  end
end
