defmodule EmailgatorWeb.Schema.Resolvers.Account do
  alias Emailgator.{Accounts, Jobs.PollInbox}

  def list(_parent, _args, %{context: %{current_user: %{id: user_id}}}) do
    {:ok, Accounts.list_user_accounts(user_id)}
  end

  def list(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def get_connect_url(_parent, _args, %{context: %{current_user: user}}) when not is_nil(user) do
    # Build absolute URL to the Gmail connect endpoint using Endpoint URL config
    endpoint_url =
      Application.get_env(:emailgator_api, EmailgatorWeb.Endpoint, []) |> Keyword.get(:url, [])

    scheme = Keyword.get(endpoint_url, :scheme, "http")
    raw_host = Keyword.get(endpoint_url, :host, "localhost")
    # Normalize host in case PHX_HOST incorrectly includes a scheme
    host =
      raw_host
      |> to_string()
      |> String.replace(~r/^https?:\/\//, "")
      |> String.trim_leading("/")

    port = Keyword.get(endpoint_url, :port, 4000)
    port_part = if port in [80, 443], do: "", else: ":#{port}"

    {:ok, "#{scheme}://#{host}#{port_part}/gmail/connect"}
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

  def polling_status(_parent, args, %{context: %{current_user: %{id: user_id}}}) do
    import Ecto.Query
    alias Emailgator.Repo

    account_id = Map.get(args, :account_id)

    # Build query based on whether account_id is provided
    query =
      if account_id do
        # Verify account belongs to user
        case Accounts.get_account(account_id) do
          nil ->
            {:error, "Account not found"}

          account ->
            if account.user_id == user_id do
              from(j in Oban.Job,
                where:
                  j.queue == "poll" and
                    j.state in ["available", "executing", "scheduled"] and
                    fragment("?->>'account_id'", j.args) == ^to_string(account_id)
              )
            else
              {:error, "Account does not belong to user"}
            end
        end
      else
        # Check all user's accounts
        account_ids =
          Accounts.list_user_accounts(user_id)
          |> Enum.map(& &1.id)
          |> Enum.map(&to_string/1)

        if Enum.empty?(account_ids) do
          {:ok, false}
        else
          # Check if any executing poll jobs have account_id in args matching user's accounts
          # Use a simpler approach: check each account_id and see if any match
          result =
            account_ids
            |> Enum.any?(fn account_id_str ->
              query =
                from(j in Oban.Job,
                  where:
                    j.queue == "poll" and
                      j.state in ["available", "executing", "scheduled"] and
                      fragment("?->>'account_id'", j.args) == ^account_id_str
                )

              Repo.exists?(query)
            end)

          {:ok, result}
        end
      end

    # Handle the result - either an error tuple, ok tuple, or a query to execute
    case query do
      {:error, _} = error ->
        error

      {:ok, _} = result ->
        # Already handled (empty account_ids case or multiple accounts check)
        result

      _query ->
        # Execute query and return count
        count = Repo.aggregate(query, :count, :id)
        {:ok, count > 0}
    end
  end

  def polling_status(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end
end
