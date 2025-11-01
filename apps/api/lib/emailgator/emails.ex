defmodule Emailgator.Emails do
  @moduledoc """
  Context for managing emails.
  """
  import Ecto.Query
  alias Emailgator.Repo
  alias Emailgator.Emails.Email

  def list_category_emails(category_id) do
    from(e in Email, where: e.category_id == ^category_id, order_by: [desc: e.inserted_at])
    |> Repo.all()
  end

  def list_account_emails(account_id) do
    from(e in Email, where: e.account_id == ^account_id, order_by: [desc: e.inserted_at])
    |> Repo.all()
  end

  def get_email(id), do: Repo.get(Email, id)
  def get_email!(id), do: Repo.get!(Email, id)

  def get_email_by_gmail_id(account_id, gmail_message_id) do
    Repo.get_by(Email, account_id: account_id, gmail_message_id: gmail_message_id)
  end

  def create_email(attrs \\ %{}) do
    %Email{}
    |> Email.changeset(attrs)
    |> Repo.insert()
  end

  def update_email(%Email{} = email, attrs) do
    email
    |> Email.changeset(attrs)
    |> Repo.update()
  end

  def delete_email(%Email{} = email) do
    Repo.delete(email)
  end

  def delete_emails(ids) when is_list(ids) do
    from(e in Email, where: e.id in ^ids)
    |> Repo.delete_all()
  end
end
