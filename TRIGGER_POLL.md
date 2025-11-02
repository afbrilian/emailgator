# How to Trigger Email Polling Manually

## Option 1: GraphQL Mutation (from Frontend)
The `triggerPoll` mutation requires authentication via session cookies. Use it from your frontend:

```javascript
// In browser console on localhost:3000
fetch('http://localhost:4000/api/graphql', {
  method: 'POST',
  credentials: 'include',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    query: 'mutation { triggerPoll }'
  })
}).then(r => r.json()).then(console.log)
```

## Option 2: IEx Console (Recommended for Testing)

1. Connect to your Phoenix server's IEx console:
   ```bash
   cd apps/api
   iex -S mix phx.server
   ```

2. Run this code:
   ```elixir
   alias Emailgator.{Accounts, Jobs.PollInbox}

   # Poll all active accounts
   Accounts.list_active_accounts()
   |> Enum.each(fn account ->
     %{account_id: account.id}
     |> PollInbox.new()
     |> Oban.insert()
   end)
   ```

   Or poll a specific account:
   ```elixir
   # Get account ID first
   account = Accounts.list_active_accounts() |> List.first()
   
   # Trigger polling
   %{account_id: account.id}
   |> PollInbox.new()
   |> Oban.insert()
   ```

## Option 3: GraphiQL with Manual Cookie

GraphiQL doesn't send cookies automatically. If you want to use GraphiQL:

1. First, log in via your frontend (http://localhost:3000)
2. Open browser DevTools → Application → Cookies
3. Copy the `_emailgator_key` cookie value
4. In GraphiQL, you'd need to configure custom headers (if your GraphiQL supports it)

**Note:** For easier testing, use Option 2 (IEx console) or Option 1 (browser console on frontend).

# How to delete existing polls

```elixir
import Ecto.Query
from(j in Oban.Job, where: j.queue == "import" and j.state == "discarded")
|> Emailgator.Repo.delete_all()
```
