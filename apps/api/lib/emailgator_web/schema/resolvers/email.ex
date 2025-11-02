defmodule EmailgatorWeb.Schema.Resolvers.Email do
  alias Emailgator.{Emails, Jobs.Unsubscribe, Accounts}
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
    results =
      email_ids
      |> Enum.map(fn email_id ->
        case Emails.get_email(email_id) do
          nil ->
            %{email_id: email_id, success: false, error: "Email not found"}

          _email ->
            %{email_id: email_id}
            |> Unsubscribe.new()
            |> Oban.insert()

            %{email_id: email_id, success: true, error: nil}
        end
      end)

    {:ok, results}
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
end
