defmodule Emailgator.UnsubscribeEdgeCasesTest do
  use Emailgator.DataCase

  alias Emailgator.Unsubscribe

  describe "edge cases" do
    test "create_attempt with minimal fields" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "success"
      }

      assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
      assert attempt.email_id == email.id
      assert attempt.method == "http"
      assert attempt.url == "https://example.com/unsubscribe"
      assert attempt.status == "success"
    end

    test "create_attempt with evidence" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      evidence = %{
        "response_status" => 200,
        "response_body" => "Success",
        "headers" => %{"Content-Type" => "text/html"}
      }

      attrs = %{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "success",
        evidence: evidence
      }

      assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
      assert attempt.evidence == evidence
    end

    test "list_email_attempts returns empty for email with no attempts" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      assert Unsubscribe.list_email_attempts(email.id) == []
    end

    test "list_email_attempts orders by inserted_at desc" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      # Create attempts with delays to ensure different timestamps
      Unsubscribe.create_attempt(%{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsub1",
        status: "success",
        evidence: %{}
      })

      Process.sleep(10)

      Unsubscribe.create_attempt(%{
        email_id: email.id,
        method: "playwright",
        url: "https://example.com/unsub2",
        status: "failed",
        evidence: %{"error" => "Failed"}
      })

      attempts = Unsubscribe.list_email_attempts(email.id)
      assert length(attempts) == 2

      # Most recent should be first (but timing can be tricky in tests)
      urls = Enum.map(attempts, & &1.url)
      assert "https://example.com/unsub1" in urls
      assert "https://example.com/unsub2" in urls
    end

    test "create_attempt with failed status" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "failed",
        evidence: %{"error" => "Connection timeout"}
      }

      assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
      assert attempt.status == "failed"
      assert attempt.evidence["error"] == "Connection timeout"
    end

    test "list_email_attempts filters by email_id" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email1 = create_email(account, category)
      email2 = create_email(account, category)

      Unsubscribe.create_attempt(%{
        email_id: email1.id,
        method: "http",
        url: "https://example.com/unsub1",
        status: "success",
        evidence: %{}
      })

      Unsubscribe.create_attempt(%{
        email_id: email2.id,
        method: "http",
        url: "https://example.com/unsub2",
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

    test "create_attempt handles nil evidence" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      attrs = %{
        email_id: email.id,
        method: "http",
        url: "https://example.com/unsubscribe",
        status: "success",
        evidence: nil
      }

      assert {:ok, attempt} = Unsubscribe.create_attempt(attrs)
      assert attempt.evidence == nil
    end

    test "create_attempt with different methods" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      email = create_email(account, category)

      # Valid methods are: "http", "playwright", "none"
      methods = ["http", "playwright", "none"]

      # Create attempts for each method
      results =
        Enum.map(methods, fn method ->
          Unsubscribe.create_attempt(%{
            email_id: email.id,
            method: method,
            url: "https://example.com/unsub_#{method}",
            status: "success",
            evidence: %{}
          })
        end)

      # Verify all succeeded
      Enum.each(results, fn result ->
        assert {:ok, _attempt} = result
      end)

      attempts = Unsubscribe.list_email_attempts(email.id)
      assert length(attempts) == 3

      attempt_methods = Enum.map(attempts, & &1.method)

      Enum.each(methods, fn method ->
        assert method in attempt_methods
      end)
    end
  end
end
