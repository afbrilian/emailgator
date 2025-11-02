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

  @doc """
  Get account with valid access token, refreshing if needed.
  """
  def get_account_with_valid_token(account_id) do
    require Logger
    Logger.info("Accounts.get_account_with_valid_token: Called for account_id: #{account_id}")

    case get_account(account_id) do
      nil ->
        Logger.warning("Accounts.get_account_with_valid_token: Account #{account_id} not found")
        nil

      account ->
        Logger.info("Accounts.get_account_with_valid_token: Found account, checking token expiration. expires_at: #{inspect(account.expires_at)}")

        if token_expired?(account) do
          Logger.info("Accounts.get_account_with_valid_token: Token expired, refreshing...")
          refresh_account_token(account)
        else
          Logger.info("Accounts.get_account_with_valid_token: Token is valid, returning account")
          {:ok, account}
        end
    end
  end

  defp token_expired?(%Account{} = account) do
    case account.expires_at do
      nil ->
        true
      expires_at ->
        comparison = DateTime.compare(DateTime.utc_now(), expires_at)
        expired = comparison != :lt
        expired
    end
  end

  defp refresh_account_token(%Account{} = account) do
    require Logger
    Logger.info("Accounts.refresh_account_token: Starting token refresh for account #{account.id}")

    case Emailgator.Gmail.refresh_token(account) do
      {:ok, new_token, expires_at} ->
        Logger.info("Accounts.refresh_account_token: Token refresh successful, updating account")
        case update_account(account, %{
               access_token: new_token,
               expires_at: expires_at
             }) do
          {:ok, updated_account} ->
            Logger.info("Accounts.refresh_account_token: Account updated successfully")
            {:ok, updated_account}
          {:error, reason} = error ->
            Logger.error("Accounts.refresh_account_token: Failed to update account: #{inspect(reason)}")
            error
        end

      {:error, reason} = error ->
        Logger.error("Accounts.refresh_account_token: Token refresh failed: #{inspect(reason)}")
        error
    end
  end
end
