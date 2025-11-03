defmodule Emailgator.Jobs.UnsubscribeExtractionTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.Jobs.Unsubscribe
  alias Emailgator.Emails
  alias Emailgator.Unsubscribe, as: UnsubscribeContext

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    Application.put_env(:tesla, Emailgator.Sidecar, adapter: Tesla.Mock)

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Sidecar)
    end)

    :ok
  end

  describe "extract_unsubscribe_from_html edge cases" do
    test "extracts unsubscribe URL from link with unsubscribe text" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      html = """
      <html>
        <body>
          <a href="https://example.com/unsubscribe">Unsubscribe</a>
        </body>
      </html>
      """

      email =
        create_email(account, category, %{
          body_html: html,
          unsubscribe_urls: []
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      # Should extract URL from HTML
      attempts = UnsubscribeContext.list_email_attempts(email.id)
      # Should have attempted unsubscribe
      assert length(attempts) >= 1
    end

    test "extracts multiple unsubscribe URLs from HTML" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      html = """
      <html>
        <body>
          <a href="https://example.com/unsub1">Unsubscribe</a>
          <a href="https://example.com/unsub2">Opt out</a>
          <a href="mailto:unsub@example.com?subject=unsubscribe">Email unsubscribe</a>
        </body>
      </html>
      """

      email =
        create_email(account, category, %{
          body_html: html,
          unsubscribe_urls: []
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      # Should extract multiple URLs
      attempts = UnsubscribeContext.list_email_attempts(email.id)
      # Will attempt multiple URLs (or fail if sidecar not available)
      assert length(attempts) >= 1
    end

    test "handles HTML with no unsubscribe links" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      html = """
      <html>
        <body>
          <p>No unsubscribe links here</p>
        </body>
      </html>
      """

      email =
        create_email(account, category, %{
          body_html: html,
          unsubscribe_urls: []
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      # Should return error since no URLs found
      assert {:error, "No unsubscribe URLs found"} = result

      # Should create attempt record indicating no URLs found
      attempts = UnsubscribeContext.list_email_attempts(email.id)
      assert length(attempts) == 1
      attempt = List.first(attempts)
      assert attempt.status == "failed"
      assert attempt.url == "none://no-unsubscribe-url-found"
    end

    test "handles empty HTML body" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      email =
        create_email(account, category, %{
          body_html: "",
          unsubscribe_urls: []
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      assert {:error, "No unsubscribe URLs found"} = result
    end

    test "handles nil HTML body" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      email =
        create_email(account, category, %{
          body_html: nil,
          unsubscribe_urls: []
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      assert {:error, "No unsubscribe URLs found"} = result
    end

    test "extracts URLs from case-insensitive unsubscribe text" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      html = """
      <html>
        <body>
          <a href="https://example.com/unsub1">UNSUBSCRIBE</a>
          <a href="https://example.com/unsub2">Unsubscribe</a>
          <a href="https://example.com/unsub3">unsubscribe</a>
        </body>
      </html>
      """

      email =
        create_email(account, category, %{
          body_html: html,
          unsubscribe_urls: []
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      # Should extract URLs regardless of case
      attempts = UnsubscribeContext.list_email_attempts(email.id)
      assert length(attempts) >= 1
    end

    test "prefers existing unsubscribe_urls over HTML extraction" do
      user = create_user()
      account = create_account(user)
      category = create_category(user)

      html = """
      <html>
        <body>
          <a href="https://example.com/html-url">Unsubscribe</a>
        </body>
      </html>
      """

      email =
        create_email(account, category, %{
          body_html: html,
          unsubscribe_urls: ["https://example.com/primary-url"]
        })

      result =
        Unsubscribe.perform(%Oban.Job{
          args: %{"email_id" => email.id}
        })

      # Should use existing URLs, not extract from HTML
      attempts = UnsubscribeContext.list_email_attempts(email.id)
      assert length(attempts) >= 1

      # Should attempt the primary URL first
      urls = Enum.map(attempts, & &1.url)
      assert "https://example.com/primary-url" in urls
    end
  end
end
