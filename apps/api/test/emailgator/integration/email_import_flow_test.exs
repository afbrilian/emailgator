defmodule Emailgator.Integration.EmailImportFlowTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.{Accounts, Emails, Categories, Jobs.ImportEmail, Jobs.PollInbox}

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)
    Application.put_env(:tesla, Emailgator.LLM, adapter: Tesla.Mock)

    Application.put_env(:emailgator_api, :openai,
      api_key: "test-key",
      base_url: "http://localhost:4003"
    )

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
      Application.delete_env(:tesla, Emailgator.LLM)
    end)

    :ok
  end

  describe "full email import flow" do
    test "complete flow from poll to import to archive" do
      user = create_user()

      account =
        create_account(user, %{
          last_history_id: nil,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user, %{name: "Work", description: "Work emails"})

      # Step 1: Poll inbox
      mock(fn
        %{method: :get, url: url} ->
          cond do
            String.contains?(url, "/users/me/messages") and String.contains?(url, "in:inbox") ->
              mock_json(%{
                "messages" => [%{"id" => "msg123"}]
              })

            String.contains?(url, "/users/me/profile") ->
              mock_json(%{"historyId" => "100"})

            String.contains?(url, "/users/me/messages/msg123") ->
              mock_json(%{
                "id" => "msg123",
                "snippet" => "Meeting tomorrow",
                "payload" => %{
                  "headers" => [
                    %{"name" => "Subject", "value" => "Meeting Tomorrow"},
                    %{"name" => "From", "value" => "boss@company.com"}
                  ],
                  "mimeType" => "text/plain",
                  "body" => %{
                    "data" =>
                      Base.url_encode64("We need to discuss the project tomorrow at 2 PM.")
                  }
                }
              })

            true ->
              %Tesla.Env{status: 404}
          end

        %{method: :post, url: url} ->
          cond do
            String.contains?(url, "/chat/completions") ->
              mock_json(%{
                "choices" => [
                  %{
                    "message" => %{
                      "content" =>
                        Jason.encode!(%{
                          "category_id" => category.id,
                          "summary" => "Meeting reminder for tomorrow at 2 PM",
                          "unsubscribe_urls" => []
                        })
                    }
                  }
                ]
              })

            String.contains?(url, "/modify") ->
              mock_json(%{"id" => "msg123"})

            true ->
              %Tesla.Env{status: 404}
          end
      end)

      # Poll inbox
      assert :ok = PollInbox.perform(%Oban.Job{args: %{"account_id" => account.id}})

      # Verify account history_id updated
      updated_account = Accounts.get_account(account.id)
      assert updated_account.last_history_id == "100"

      # Verify import job was queued
      import Ecto.Query
      import_jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "import"))
      assert length(import_jobs) == 1

      # Run import job
      import_job = List.first(import_jobs)
      assert :ok = ImportEmail.perform(import_job)

      # Verify email was created
      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      assert email != nil
      assert email.subject == "Meeting Tomorrow"
      assert email.from == "boss@company.com"
      assert email.category_id == category.id
      assert email.summary == "Meeting reminder for tomorrow at 2 PM"

      # Verify archive job was queued
      archive_jobs = Emailgator.Repo.all(from(j in Oban.Job, where: j.queue == "archive"))
      assert length(archive_jobs) == 1
    end

    test "handles duplicate email import gracefully" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      # Create email first
      existing_email = create_email(account, category, %{gmail_message_id: "msg123"})

      mock(fn
        %{method: :get} ->
          mock_json(%{
            "id" => "msg123",
            "snippet" => "Test",
            "payload" => %{
              "headers" => [%{"name" => "Subject", "value" => "Test"}],
              "mimeType" => "text/plain",
              "body" => %{"data" => Base.url_encode64("Body")}
            }
          })
      end)

      # Import should skip existing email
      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      # Verify only one email exists
      emails = Emails.list_account_emails(account.id)
      assert length(emails) == 1
      assert List.first(emails).id == existing_email.id
    end
  end
end
