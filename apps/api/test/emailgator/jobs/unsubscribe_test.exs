defmodule Emailgator.Jobs.UnsubscribeTest do
  use Emailgator.DataCase

  alias Emailgator.Jobs.Unsubscribe

  test "perform/1 returns cancel when email not found" do
    fake_email_id = Ecto.UUID.generate()

    assert {:cancel, "Email not found"} =
             Unsubscribe.perform(%Oban.Job{
               args: %{"email_id" => fake_email_id}
             })
  end

  test "perform/1 creates failed attempt when no unsubscribe URLs found" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    email = create_email(account, category, %{
      unsubscribe_urls: [],
      body_html: nil
    })

    result = Unsubscribe.perform(%Oban.Job{
      args: %{"email_id" => email.id}
    })

    # Should return error since no URLs found
    assert {:error, _reason} = result

    # Verify attempt was created with url set to empty string (not null)
    attempts = Emailgator.Unsubscribe.list_email_attempts(email.id)
    assert length(attempts) >= 1
    failed_attempt = Enum.find(attempts, & &1.status == "failed")
    assert failed_attempt.status == "failed"
    assert failed_attempt.method == "none"
    assert failed_attempt.url == "none://no-unsubscribe-url-found"
  end
end
