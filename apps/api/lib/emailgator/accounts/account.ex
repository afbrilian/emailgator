defmodule Emailgator.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset
  alias Emailgator.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "accounts" do
    field(:email, :string)
    field(:access_token, :string)
    field(:refresh_token, :string)
    field(:expires_at, :utc_datetime)
    field(:last_history_id, :string)
    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :email,
      :access_token,
      :refresh_token,
      :expires_at,
      :last_history_id,
      :user_id
    ])
    |> validate_required([:email, :access_token, :refresh_token, :user_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> unique_constraint([:user_id, :email])
  end
end
