defmodule EmailgatorWeb.Schema.Context do
  @behaviour Plug

  import Plug.Conn
  alias Emailgator.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user = get_session_user(conn)
    Absinthe.Plug.put_options(conn, context: %{current_user: user})
  end

  defp get_session_user(conn) do
    case get_session(conn, :user_id) do
      nil -> nil
      user_id -> Accounts.get_user(user_id)
    end
  end
end
