defmodule EmailgatorWeb.Schema.Types do
  use Absinthe.Schema.Notation
  alias Jason

  scalar :datetime do
    description("ISO8601 datetime")
    serialize(&serialize_datetime/1)
    parse(&parse_datetime/1)
  end

  scalar :json do
    description("JSON object")
    serialize(&serialize_json/1)
    parse(&parse_json/1)
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

    field(:is_unsubscribed, :boolean,
      resolve: &EmailgatorWeb.Schema.Resolvers.Email.is_unsubscribed/3
    )

    field(:unsubscribe_attempts, list_of(:unsubscribe_attempt),
      resolve: &EmailgatorWeb.Schema.Resolvers.Email.unsubscribe_attempts/3
    )
  end

  object :unsubscribe_result do
    field(:email_id, :id)
    field(:success, :boolean)
    field(:error, :string)
  end

  object :unsubscribe_attempt do
    field(:id, :id)
    field(:method, :string)
    field(:url, :string)
    field(:status, :string)
    field(:evidence, :json)
    field(:inserted_at, :datetime)
    field(:updated_at, :datetime)
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

  # JSON scalar serialization
  defp serialize_json(value) when is_map(value) or is_list(value) do
    value
  end

  defp serialize_json(value) when is_binary(value) do
    # If it's already a JSON string, try to parse it first
    case Jason.decode(value) do
      {:ok, parsed} -> parsed
      {:error, _} -> value
    end
  end

  defp serialize_json(nil), do: nil
  defp serialize_json(value), do: value

  defp parse_json(%Absinthe.Blueprint.Input.String{value: value}) do
    case Jason.decode(value) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> :error
    end
  end

  defp parse_json(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp parse_json(_) do
    :error
  end
end
