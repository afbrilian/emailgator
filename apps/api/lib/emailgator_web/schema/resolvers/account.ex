defmodule EmailgatorWeb.Schema.Resolvers.Account do
  alias Emailgator.{Accounts, Jobs.PollInbox}

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

  def trigger_poll(_parent, args, %{context: %{current_user: %{id: user_id}}}) do
    case Map.get(args, :account_id) do
      nil ->
        # Poll all user's active accounts
        accounts = Accounts.list_user_accounts(user_id)

        accounts
        |> Enum.filter(fn account -> not is_nil(account.refresh_token) end)
        |> Enum.each(fn account ->
          %{account_id: account.id}
          |> PollInbox.new()
          |> Oban.insert()
        end)

        {:ok, true}

      account_id ->
        # Poll specific account if it belongs to user
        case Accounts.get_account(account_id) do
          nil ->
            {:error, "Account not found"}

          account ->
            if account.user_id == user_id do
              %{account_id: account_id}
              |> PollInbox.new()
              |> Oban.insert()

              {:ok, true}
            else
              {:error, "Account does not belong to user"}
            end
        end
    end
  end

  def trigger_poll(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end
end
