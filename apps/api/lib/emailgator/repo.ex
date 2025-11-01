defmodule Emailgator.Repo do
  use Ecto.Repo,
    otp_app: :emailgator_api,
    adapter: Ecto.Adapters.Postgres
end
