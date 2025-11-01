defmodule EmailgatorWeb.Schema.Resolvers.User do
  def me(_parent, _args, %{context: %{current_user: user}}) when not is_nil(user) do
    {:ok, user}
  end

  def me(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end
end
