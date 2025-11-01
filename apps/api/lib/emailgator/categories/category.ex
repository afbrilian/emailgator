defmodule Emailgator.Categories.Category do
  use Ecto.Schema
  import Ecto.Changeset
  alias Emailgator.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field(:name, :string)
    field(:description, :string)
    belongs_to(:user, User)

    has_many(:emails, Emailgator.Emails.Email)

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 255)
  end
end
