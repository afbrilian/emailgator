defmodule Emailgator.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Emailgator.Accounts.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field(:email, :string)
    field(:name, :string)

    has_many(:accounts, Account)
    has_many(:categories, Emailgator.Categories.Category)

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> unique_constraint(:email)
  end
end
