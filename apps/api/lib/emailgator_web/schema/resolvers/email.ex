defmodule EmailgatorWeb.Schema.Resolvers.Email do
  alias Emailgator.{Emails, Repo}
  alias Emailgator.Jobs.Unsubscribe, as: UnsubscribeJob
  alias Emailgator.Unsubscribe
  alias Emailgator.Unsubscribe.UnsubscribeAttempt
  import Ecto.Query

  def list_by_category(_parent, %{category_id: category_id}, %{context: %{current_user: user}})
      when not is_nil(user) do
    {:ok, Emails.list_category_emails(category_id)}
  end

  def list_by_category(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def bulk_delete(_parent, %{email_ids: email_ids}, %{context: %{current_user: user}})
      when not is_nil(user) do
    Emails.delete_emails(email_ids)
    {:ok, email_ids}
  end

  def bulk_delete(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def bulk_unsubscribe(_parent, %{email_ids: email_ids}, %{context: %{current_user: user}})
      when not is_nil(user) do
    require Logger

    Logger.info("bulk_unsubscribe: Queuing #{length(email_ids)} unsubscribe job(s)")

    # Validate emails exist and belong to user in a single query (more efficient than N+1)
    user_email_ids =
      from(e in Emails.Email,
        join: a in assoc(e, :account),
        where: e.id in ^email_ids and a.user_id == ^user.id,
        select: e.id
      )
      |> Emailgator.Repo.all()

    invalid_email_ids = email_ids -- user_email_ids

    # Queue jobs in a transaction for better performance with large batches
    results =
      Emailgator.Repo.transaction(fn ->
        user_email_ids
        |> Enum.map(fn email_id ->
          case %{email_id: email_id}
               |> UnsubscribeJob.new()
               |> Oban.insert() do
            {:ok, _job} ->
              %{email_id: email_id, success: true, error: nil}

            {:error, changeset} ->
              Logger.warning(
                "bulk_unsubscribe: Failed to queue job for email #{email_id}: #{inspect(changeset.errors)}"
              )

              %{email_id: email_id, success: false, error: "Failed to queue job"}
          end
        end)
      end)

    case results do
      {:ok, valid_results} ->
        Logger.info(
          "bulk_unsubscribe: Successfully queued #{length(valid_results)} unsubscribe job(s)"
        )

        invalid_results =
          Enum.map(invalid_email_ids, fn email_id ->
            %{email_id: email_id, success: false, error: "Email not found or access denied"}
          end)

        {:ok, valid_results ++ invalid_results}

      {:error, reason} ->
        Logger.error("bulk_unsubscribe: Transaction failed: #{inspect(reason)}")
        {:error, "Failed to queue unsubscribe jobs"}
    end
  end

  def bulk_unsubscribe(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def get_email(_parent, %{id: email_id}, %{context: %{current_user: %{id: user_id}}}) do
    # Get email with preloaded account and category to check ownership
    query =
      from(e in Emails.Email,
        join: a in assoc(e, :account),
        where: e.id == ^email_id and a.user_id == ^user_id,
        preload: [:account, :category]
      )

    case Emailgator.Repo.one(query) do
      nil -> {:error, "Email not found"}
      email -> {:ok, email}
    end
  end

  def get_email(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def is_unsubscribed(%Emails.Email{} = email, _args, _info) do
    # Check if there's a successful unsubscribe attempt for this email
    query =
      from(u in UnsubscribeAttempt,
        where: u.email_id == ^email.id and u.status == "success",
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:ok, false}
      _attempt -> {:ok, true}
    end
  end

  def is_unsubscribed(_parent, _args, _info) do
    {:ok, false}
  end

  def unsubscribe_attempts(%Emails.Email{} = email, _args, _info) do
    attempts = Unsubscribe.list_email_attempts(email.id)
    {:ok, attempts}
  end

  def unsubscribe_attempts(_parent, _args, _info) do
    {:ok, []}
  end
end
