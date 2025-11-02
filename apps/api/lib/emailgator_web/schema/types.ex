defmodule EmailgatorWeb.Schema.Types do
  use Absinthe.Schema.Notation

  scalar :datetime do
    description("ISO8601 datetime")
    serialize(&serialize_datetime/1)
    parse(&parse_datetime/1)
  end

  object :user do
    field(:id, :id)
    field(:email, :string)
    field(:name, :string)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
  end

  object :account do
    field(:id, :id)
    field(:email, :string)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
  end

  object :category do
    field(:id, :id)
    field(:name, :string)
    field(:description, :string)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
  end

  object :email do
    field(:id, :id)
    field(:gmail_message_id, :string)
    field(:subject, :string)
    field(:from, :string)
    field(:snippet, :string)
    field(:summary, :string)
    field(:body_text, :string)
    field(:body_html, :string)
    field(:unsubscribe_urls, list_of(:string))
    field(:archived_at, :datetime)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
    field(:category, :category)
  end

  object :unsubscribe_result do
    field(:email_id, :id)
    field(:success, :boolean)
    field(:error, :string)
  end

  # Serialize DateTime or NaiveDateTime to ISO8601 string
  defp serialize_datetime(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end

  defp serialize_datetime(%NaiveDateTime{} = naive_datetime) do
    # Convert NaiveDateTime to DateTime in UTC (Ecto stores in UTC)
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp serialize_datetime(nil), do: nil
  defp serialize_datetime(_), do: nil

  defp parse_datetime(%Absinthe.Blueprint.Input.String{value: value}) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> :error
    end
  end

  defp parse_datetime(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp parse_datetime(_) do
    :error
  end
end
