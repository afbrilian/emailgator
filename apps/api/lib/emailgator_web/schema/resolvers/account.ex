defmodule EmailgatorWeb.Schema.Resolvers.Account do
  alias Emailgator.Accounts

  def list(_parent, _args, %{context: %{current_user: %{id: user_id}}}) do
    {:ok, Accounts.list_user_accounts(user_id)}
  end

  def list(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def connect(_parent, args, %{context: %{current_user: %{id: user_id}}}) do
    args
    |> Map.put(:user_id, user_id)
    |> Accounts.create_account()
  end

  def connect(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def disconnect(_parent, %{id: id}, %{context: %{current_user: user}}) when not is_nil(user) do
    case Accounts.get_account(id) do
      nil -> {:error, "Account not found"}
      account -> Accounts.delete_account(account)
    end
  end

  def disconnect(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end
end
