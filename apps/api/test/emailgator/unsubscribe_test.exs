defmodule Emailgator.UnsubscribeTest do
  use Emailgator.DataCase

  alias Emailgator.Unsubscribe
  alias Emailgator.Unsubscribe.UnsubscribeAttempt

  test "create_attempt/1 creates an unsubscribe attempt" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    email = create_email(account, category)

    attrs = %{
      email_id: email.id,
      method: "http",
      url: "https://example.com/unsubscribe",
      status: "success",
      evidence: %{"message" => "Unsubscribed successfully"}
    }

    assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
    assert attempt.email_id == email.id
    assert attempt.method == "http"
    assert attempt.url == "https://example.com/unsubscribe"
    assert attempt.status == "success"
  end

  test "create_attempt/1 validates required fields" do
    attrs = %{
      method: "http",
      url: "https://example.com/unsubscribe"
    }

    assert {:error, changeset} = Unsubscribe.create_attempt(attrs)
    assert %{email_id: ["can't be blank"]} = errors_on(changeset)
  end

  test "list_email_attempts/1 returns attempts for an email" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    email = create_email(account, category)

    # Create multiple attempts
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
      evidence: %{"error" => "Failed"}
    })

    attempts = Unsubscribe.list_email_attempts(email.id)
    assert length(attempts) == 2

    # Should be ordered by inserted_at desc (most recent first)
    # Both attempts should be present, but order depends on timing
    urls = Enum.map(attempts, & &1.url)
    assert "https://example.com/unsubscribe1" in urls
    assert "https://example.com/unsubscribe2" in urls
  end

  test "list_email_attempts/1 returns empty list when no attempts" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    email = create_email(account, category)

    attempts = Unsubscribe.list_email_attempts(email.id)
    assert attempts == []
  end

  test "list_email_attempts/1 only returns attempts for specified email" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    email1 = create_email(account, category)
    email2 = create_email(account, category)

    Unsubscribe.create_attempt(%{
      email_id: email1.id,
      method: "http",
      url: "https://example.com/unsubscribe1",
      status: "success",
      evidence: %{}
    })

    Unsubscribe.create_attempt(%{
      email_id: email2.id,
      method: "http",
      url: "https://example.com/unsubscribe2",
      status: "success",
      evidence: %{}
    })

    attempts1 = Unsubscribe.list_email_attempts(email1.id)
    attempts2 = Unsubscribe.list_email_attempts(email2.id)

    assert length(attempts1) == 1
    assert length(attempts2) == 1
    assert List.first(attempts1).email_id == email1.id
    assert List.first(attempts2).email_id == email2.id
  end
end
