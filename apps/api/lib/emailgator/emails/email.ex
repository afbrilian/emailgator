defmodule Emailgator.Emails.Email do
  use Ecto.Schema
  import Ecto.Changeset
  alias Emailgator.Accounts.Account
  alias Emailgator.Categories.Category

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "emails" do
    field(:gmail_message_id, :string)
    field(:subject, :string)
    field(:from, :string)
    field(:snippet, :string)
    field(:summary, :string)
    field(:body_text, :string)
    field(:body_html, :string)
    field(:unsubscribe_urls, {:array, :string}, default: [])
    field(:archived_at, :utc_datetime)
    belongs_to(:account, Account)
    belongs_to(:category, Category)

    has_many(:unsubscribe_attempts, Emailgator.Unsubscribe.UnsubscribeAttempt)

    timestamps()
  end

  @doc false
  def changeset(email, attrs) do
    email
    |> cast(attrs, [
      :gmail_message_id,
      :subject,
      :from,
      :snippet,
      :summary,
      :body_text,
      :body_html,
      :unsubscribe_urls,
      :archived_at,
      :account_id,
      :category_id
    ])
    |> validate_required([:gmail_message_id, :account_id])
    |> unique_constraint([:account_id, :gmail_message_id])
  end
end
