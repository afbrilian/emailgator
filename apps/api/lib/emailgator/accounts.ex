defmodule Emailgator.Accounts do
  @moduledoc """
  Context for managing users and Gmail accounts.
  """
  import Ecto.Query
  alias Emailgator.Repo
  alias Emailgator.Accounts.{User, Account}

  # Users

  def get_user(id), do: Repo.get(User, id)
  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def create_or_update_user(attrs) do
    case get_user_by_email(attrs["email"]) do
      nil -> create_user(attrs)
      user -> update_user(user, attrs)
    end
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  # Accounts (Gmail)

  def list_user_accounts(user_id) do
    from(a in Account, where: a.user_id == ^user_id)
    |> Repo.all()
  end

  def get_account(id), do: Repo.get(Account, id)

  def get_account_by_email(user_id, email),
    do: Repo.get_by(Account, user_id: user_id, email: email)

  def create_account(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def delete_account(%Account{} = account) do
    Repo.delete(account)
  end

  def list_active_accounts do
    from(a in Account, where: not is_nil(a.refresh_token))
    |> Repo.all()
  end
end
