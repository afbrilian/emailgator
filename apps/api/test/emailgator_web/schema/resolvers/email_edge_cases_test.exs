defmodule EmailgatorWeb.Schema.Resolvers.EmailEdgeCasesTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Email

  describe "list_by_category/3" do
    test "returns empty list when category has no emails" do
      user = create_user()
      category = create_category(user)
      context = build_context(user)

      assert {:ok, emails} = Email.list_by_category(nil, %{category_id: category.id}, context)
      assert emails == []
    end
  end

  describe "is_unsubscribed/3" do
    test "returns false when no attempts exist" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, false} = Email.is_unsubscribed(email, %{}, %{})
    end

    test "returns false when only failed attempts exist" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      {:ok, _attempt} =
        Emailgator.Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "http",
          url: "https://example.com/unsubscribe",
          status: "failed"
        })

      assert {:ok, false} = Email.is_unsubscribed(email, %{}, %{})
    end
  end

  describe "unsubscribe_attempts/3" do
    test "returns empty list when no attempts" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert {:ok, []} = Email.unsubscribe_attempts(email, %{}, %{})
    end

    test "returns all attempts for email" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      {:ok, attempt1} =
        Emailgator.Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "http",
          url: "https://example.com/unsubscribe",
          status: "failed"
        })

      {:ok, attempt2} =
        Emailgator.Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "playwright",
          url: "https://example.com/unsubscribe",
          status: "success"
        })

      assert {:ok, attempts} = Email.unsubscribe_attempts(email, %{}, %{})
      assert length(attempts) == 2
      # Verify both attempts are returned
      assert attempt1.id in Enum.map(attempts, & &1.id)
      assert attempt2.id in Enum.map(attempts, & &1.id)
    end
  end

  describe "bulk_unsubscribe/3 edge cases" do
    test "handles empty email_ids list" do
      user = create_user()
      context = build_context(user)

      assert {:ok, []} = Email.bulk_unsubscribe(nil, %{email_ids: []}, context)
    end

    test "handles invalid email IDs gracefully" do
      user = create_user()
      context = build_context(user)
      fake_id = Ecto.UUID.generate()

      assert {:ok, results} = Email.bulk_unsubscribe(nil, %{email_ids: [fake_id]}, context)
      assert length(results) == 1
      assert hd(results).success == false
      assert hd(results).error == "Email not found or access denied"
    end
  end
end
