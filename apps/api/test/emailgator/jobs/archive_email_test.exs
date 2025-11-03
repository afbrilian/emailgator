defmodule Emailgator.Jobs.ArchiveEmailTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.{Jobs.ArchiveEmail, Accounts, Emails}

  setup do
    # Configure Tesla to use Mock adapter for Gmail in tests
    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
    end)

    :ok
  end

  test "perform/1 returns cancel when account not found" do
    fake_account_id = Ecto.UUID.generate()

    assert {:cancel, "Account not found"} =
             ArchiveEmail.perform(%Oban.Job{
               args: %{"account_id" => fake_account_id, "message_id" => "msg123"}
             })
  end

  test "perform/1 successfully archives message" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)
    email = create_email(account, category, %{gmail_message_id: "msg123"})

    mock(fn
      %{method: :post, url: url} ->
        if String.contains?(url, "/modify") do
          %Tesla.Env{status: 200}
        else
          %Tesla.Env{status: 404}
        end
    end)

    result =
      ArchiveEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert :ok = result

    # Verify email was updated with archived_at
    updated_email = Emails.get_email(email.id)
    assert updated_email.archived_at != nil
  end

  test "perform/1 handles message not found in database" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    mock(fn
      %{method: :post} ->
        %Tesla.Env{status: 200}
    end)

    result =
      ArchiveEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "nonexistent_msg"}
      })

    assert :ok = result
  end

  test "perform/1 handles rate limit errors with snooze" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)
    create_email(account, category, %{gmail_message_id: "msg123"})

    mock(fn
      %{method: :post} ->
        %Tesla.Env{
          status: 429,
          body: %{"error" => "Rate limit exceeded"}
        }
    end)

    result =
      ArchiveEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert {:snooze, 300} = result
  end

  test "perform/1 handles Gmail API errors" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)
    create_email(account, category, %{gmail_message_id: "msg123"})

    mock(fn
      %{method: :post} ->
        %Tesla.Env{
          status: 403,
          body: %{"error" => "Forbidden"}
        }
    end)

    result =
      ArchiveEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert {:error, _reason} = result
  end
end
