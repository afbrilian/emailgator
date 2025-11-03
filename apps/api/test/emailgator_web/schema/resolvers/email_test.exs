defmodule EmailgatorWeb.Schema.Resolvers.EmailTest do
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Email
  alias Emailgator.{Emails, Unsubscribe}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Emailgator.Repo)
    :ok
  end

  describe "list_by_category/3" do
    test "returns emails for category when authenticated" do
      user = create_user()
      account = create_account(user)
      category1 = create_category(user)
      category2 = create_category(user)
      email1 = create_email(account, category1)
      email2 = create_email(account, category1)
      _email3 = create_email(account, category2)

      context = %{context: %{current_user: user}}
      assert {:ok, emails} = Email.list_by_category(nil, %{category_id: category1.id}, context)

      email_ids = Enum.map(emails, & &1.id)
      assert email1.id in email_ids
      assert email2.id in email_ids
      assert length(emails) == 2
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}

      assert {:error, "Not authenticated"} =
               Email.list_by_category(nil, %{category_id: "test"}, context)
    end
  end

  describe "get_email/3" do
    test "returns email when it exists and belongs to user" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:ok, found_email} = Email.get_email(nil, %{id: email.id}, context)
      assert found_email.id == email.id
    end

    test "returns error when email not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: %{id: user.id}}}

      assert {:error, "Email not found"} = Email.get_email(nil, %{id: fake_id}, context)
    end

    test "returns error when email doesn't belong to user" do
      user1 = create_user()
      user2 = create_user()
      account2 = create_account(user2)
      category2 = create_category(user2)
      email2 = create_email(account2, category2)
      context = %{context: %{current_user: %{id: user1.id}}}

      assert {:error, "Email not found"} = Email.get_email(nil, %{id: email2.id}, context)
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Email.get_email(nil, %{id: "test"}, context)
    end
  end

  describe "bulk_delete/3" do
    test "deletes emails when authenticated" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category)
      email2 = create_email(account, category)
      context = %{context: %{current_user: user}}

      assert {:ok, deleted_ids} =
               Email.bulk_delete(nil, %{email_ids: [email1.id, email2.id]}, context)

      assert email1.id in deleted_ids
      assert email2.id in deleted_ids

      assert Emails.get_email(email1.id) == nil
      assert Emails.get_email(email2.id) == nil
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Email.bulk_delete(nil, %{email_ids: []}, context)
    end
  end

  describe "bulk_unsubscribe/3" do
    test "queues unsubscribe jobs when authenticated" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      email1 =
        create_email(account, category, %{unsubscribe_urls: ["https://example.com/unsub1"]})

      email2 =
        create_email(account, category, %{unsubscribe_urls: ["https://example.com/unsub2"]})

      context = %{context: %{current_user: user}}

      assert {:ok, results} =
               Email.bulk_unsubscribe(nil, %{email_ids: [email1.id, email2.id]}, context)

      assert length(results) == 2

      # Verify jobs were queued
      import Ecto.Query
      jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "unsubscribe"))
      assert length(jobs) >= 2
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}

      assert {:error, "Not authenticated"} =
               Email.bulk_unsubscribe(nil, %{email_ids: []}, context)
    end
  end

  describe "is_unsubscribed/3" do
    test "returns true when successful unsubscribe attempt exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      # Create successful unsubscribe attempt
      Unsubscribe.create_attempt(%{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "success",
        evidence: %{}
      })

      assert {:ok, true} = Email.is_unsubscribed(email, %{}, %{})
    end

    test "returns false when no successful unsubscribe attempt exists" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, false} = Email.is_unsubscribed(email, %{}, %{})
    end

    test "returns false when unsubscribe attempt failed" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      # Create failed unsubscribe attempt
      Unsubscribe.create_attempt(%{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "failed",
        evidence: %{error: "Failed"}
      })

      assert {:ok, false} = Email.is_unsubscribed(email, %{}, %{})
    end

    test "returns false for non-email parent" do
      assert {:ok, false} = Email.is_unsubscribed(nil, %{}, %{})
    end
  end

  describe "unsubscribe_attempts/3" do
    test "returns attempts for email" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      Unsubscribe.create_attempt(%{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe1",
        status: "success",
        evidence: %{}
      })

      Unsubscribe.create_attempt(%{
        email_id: email.id,
        method: "playwright",
        url: "https://example.com/unsubscribe2",
        status: "failed",
        evidence: %{error: "Failed"}
      })

      assert {:ok, attempts} = Email.unsubscribe_attempts(email, %{}, %{})
      assert length(attempts) == 2
    end

    test "returns empty list when no attempts" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, []} = Email.unsubscribe_attempts(email, %{}, %{})
    end

    test "returns empty list for non-email parent" do
      assert {:ok, []} = Email.unsubscribe_attempts(nil, %{}, %{})
    end
  end
end
