defmodule EmailgatorWeb.Schema.Resolvers.Account do
  alias Emailgator.Accounts

  def list(_parent, _args, %{context: %{current_user: %{id: user_id}}}) do
    {:ok, Accounts.list_user_accounts(user_id)}
  end

  def list(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def get_connect_url(_parent, _args, %{context: %{current_user: user}}) when not is_nil(user) do
    # Return the URL to redirect to for Gmail OAuth
    # Frontend will handle the redirect
    endpoint_config = Application.get_env(:emailgator_api, EmailgatorWeb.Endpoint, [])
    host = Keyword.get(endpoint_config, :url, []) |> Keyword.get(:host, "localhost")
    port = 4000
    scheme = "http"

    {:ok, "#{scheme}://#{host}:#{port}/gmail/connect"}
  end

  def get_connect_url(_parent, _args, _context) do
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
