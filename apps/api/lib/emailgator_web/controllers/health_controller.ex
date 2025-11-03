defmodule EmailgatorWeb.HealthController do
  use EmailgatorWeb, :controller

  def health(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
  end
end
