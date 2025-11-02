defmodule Emailgator.UnsubscribeTest do
  use Emailgator.DataCase

  alias Emailgator.Unsubscribe

  describe "create_attempt/1" do
    test "creates unsubscribe attempt with valid attributes" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{
        email_id: email.id,
        method: "playwright",
        url: "https://example.com/unsubscribe",
        status: "success"
      }

      assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
      assert attempt.email_id == email.id
      assert attempt.method == "playwright"
      assert attempt.status == "success"
    end

    test "creates failed attempt" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "failed",
        evidence: %{error: "Connection timeout"}
      }

      assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
      assert attempt.status == "failed"
    end
  end

  describe "list_email_attempts/1" do
    test "returns attempts for email" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      {:ok, attempt1} =
        Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "http",
          url: "https://example.com/unsubscribe",
          status: "failed"
        })

      {:ok, attempt2} =
        Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "playwright",
          url: "https://example.com/unsubscribe",
          status: "success"
        })

      # Create attempt for different email
      email2 = create_email(account, category)
      {:ok, _attempt3} =
        Unsubscribe.create_attempt(%{
          email_id: email2.id,
          method: "http",
          url: "https://other.com/unsubscribe",
          status: "failed"
        })

      attempts = Unsubscribe.list_email_attempts(email.id)
      assert length(attempts) == 2
      assert attempt1.id in Enum.map(attempts, & &1.id)
      assert attempt2.id in Enum.map(attempts, & &1.id)
    end

    test "returns empty list when no attempts exist" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attempts = Unsubscribe.list_email_attempts(email.id)
      assert attempts == []
    end
  end
end
