defmodule Emailgator.Unsubscribe.UnsubscribeAttempt do
  use Ecto.Schema
  import Ecto.Changeset
  alias Emailgator.Emails.Email

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "unsubscribe_attempts" do
    field(:method, :string)
    field(:url, :string)
    field(:status, :string)
    field(:evidence, :map)
    belongs_to(:email, Email)

    timestamps()
  end

  @doc false
  def changeset(attempt, attrs) do
    attempt
    |> cast(attrs, [:method, :url, :status, :evidence, :email_id])
    |> validate_required([:method, :status, :email_id])
    |> validate_inclusion(:status, ["success", "failed"])
    |> validate_inclusion(:method, ["http", "playwright", "none"])
  end
end
