defmodule Emailgator.IntegrationTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.{Accounts, Emails, Categories, Gmail, LLM}
  alias Emailgator.Jobs.{ImportEmail, PollInbox, ArchiveEmail}

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)
    Application.put_env(:tesla, Emailgator.LLM, adapter: Tesla.Mock)

    Application.put_env(:emailgator_api, :openai,
      api_key: "test-key",
      base_url: "http://localhost:4003"
    )

    System.put_env("GOOGLE_CLIENT_ID", "test_client_id")
    System.put_env("GOOGLE_CLIENT_SECRET", "test_client_secret")

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
      Application.delete_env(:tesla, Emailgator.LLM)
    end)

    :ok
  end

  describe "end-to-end email import flow" do
    test "complete flow from poll to import to archive" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: nil,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      # Step 1: Poll inbox finds new messages
      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") and String.contains?(url, "in:inbox") ->
              mock_json(%{
                "messages" => [%{"id" => "msg1"}, %{"id" => "msg2"}]
              })

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "history123"})

            String.contains?(url, "/users/me/messages/msg1") ->
              mock_json(%{
                "id" => "msg1",
                "snippet" => "Test snippet",
                "payload" => %{
                  "headers" => [
                    %{"name" => "Subject", "value" => "Test Email"},
                    %{"name" => "From", "value" => "test@example.com"}
                  ],
                  "mimeType" => "text/plain",
                  "body" => %{"data" => Base.url_encode64("Test body")}
                }
              })

            true ->
              %Tesla.Env{status: 404}
          end

        %{method: :post, url: url} ->
          if String.contains?(url, "/chat/completions") do
            mock_json(%{
              "choices" => [
                %{
                  "message" => %{
                    "content" =>
                      Jason.encode!(%{
                        "category_id" => category.id,
                        "summary" => "Test summary",
                        "unsubscribe_urls" => []
                      })
                  }
                }
              ]
            })
          else
            %Tesla.Env{status: 200}
          end
      end)

      # Poll inbox
      result =
        PollInbox.perform(%Oban.Job{
          args: %{"account_id" => account.id}
        })

      assert :ok = result

      # Verify import jobs were queued
      import_jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "import"))
      assert length(import_jobs) >= 2

      # Step 2: Import email
      import_result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg1"}
        })

      assert :ok = import_result

      # Verify email was created
      email = Emails.get_email_by_gmail_id(account.id, "msg1")
      assert email != nil
      assert email.category_id == category.id

      # Step 3: Archive email
      archive_result =
        ArchiveEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg1"}
        })

      assert :ok = archive_result

      # Verify email was archived
      updated_email = Emails.get_email(email.id)
      assert updated_email.archived_at != nil
    end

    test "handles account token refresh during import" do
      user = create_user()

      account =
        create_account(user, %{
          # Expired
          expires_at: DateTime.add(DateTime.utc_now(), -100, :second),
          refresh_token: "valid_refresh_token"
        })

      category = create_category(user)

      # Mock Gmail to return expired token, then refresh (will fail with test creds)
      mock(fn
        %{method: :get} ->
          %Tesla.Env{status: 401, body: %{"error" => "Invalid credentials"}}

        %{method: :post} ->
          %Tesla.Env{status: 200, body: %{"choices" => []}}
      end)

      # Import will attempt refresh but fail with test credentials
      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg1"}
        })

      # Should return error due to failed refresh
      assert {:error, _reason} = result
    end
  end

  describe "category management flow" do
    test "user can create, update, and delete category" do
      user = create_user()

      # Create
      {:ok, category} =
        Categories.create_category(%{
          name: "Work",
          description: "Work emails",
          user_id: user.id
        })

      assert category.name == "Work"

      # Update
      {:ok, updated} = Categories.update_category(category, %{name: "Work Updated"})
      assert updated.name == "Work Updated"

      # Delete
      {:ok, _deleted} = Categories.delete_category(updated)
      assert Categories.get_category(category.id) == nil
    end

    test "user can create multiple categories and list them" do
      user = create_user()

      cat1 = create_category(user, %{name: "Category 1"})
      cat2 = create_category(user, %{name: "Category 2"})
      cat3 = create_category(user, %{name: "Category 3"})

      categories = Categories.list_user_categories(user.id)
      category_ids = Enum.map(categories, & &1.id)

      assert cat1.id in category_ids
      assert cat2.id in category_ids
      assert cat3.id in category_ids
      assert length(categories) == 3
    end
  end

  describe "account management flow" do
    test "user can create and manage multiple accounts" do
      user = create_user()

      account1 = create_account(user, %{email: "account1@example.com"})
      account2 = create_account(user, %{email: "account2@example.com"})

      accounts = Accounts.list_user_accounts(user.id)
      account_ids = Enum.map(accounts, & &1.id)

      assert account1.id in account_ids
      assert account2.id in account_ids

      # Delete one account
      {:ok, _deleted} = Accounts.delete_account(account1)

      accounts_after = Accounts.list_user_accounts(user.id)
      assert length(accounts_after) == 1
      assert List.first(accounts_after).id == account2.id
    end

    test "user can update account details" do
      user = create_user()
      account = create_account(user)

      {:ok, updated} =
        Accounts.update_account(account, %{
          last_history_id: "new_history_123"
        })

      assert updated.last_history_id == "new_history_123"
    end
  end

  describe "email categorization flow" do
    test "emails are correctly categorized and listed" do
      user = create_user()
      account = create_account(user)
      work_category = create_category(user, %{name: "Work"})
      personal_category = create_category(user, %{name: "Personal"})

      email1 = create_email(account, work_category)
      email2 = create_email(account, work_category)
      email3 = create_email(account, personal_category)

      work_emails = Emails.list_category_emails(work_category.id)
      personal_emails = Emails.list_category_emails(personal_category.id)

      assert length(work_emails) == 2
      assert length(personal_emails) == 1

      work_email_ids = Enum.map(work_emails, & &1.id)
      assert email1.id in work_email_ids
      assert email2.id in work_email_ids
      assert email3.id not in work_email_ids
    end
  end
end
