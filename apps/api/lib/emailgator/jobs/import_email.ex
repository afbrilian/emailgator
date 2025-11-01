defmodule Emailgator.Jobs.ImportEmail do
  @moduledoc """
  Imports a single email: fetches from Gmail, classifies with LLM, saves to DB, then archives.
  """
  use Oban.Worker, queue: :import, max_attempts: 3
  alias Emailgator.{Accounts, Categories, Emails, Gmail, LLM, Jobs.ArchiveEmail}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id, "message_id" => message_id}}) do
    account = Accounts.get_account(account_id)

    if is_nil(account) do
      {:cancel, "Account not found"}
    else
      # Check if email already imported
      if Emails.get_email_by_gmail_id(account_id, message_id) do
        :ok
      else
        import_email(account, message_id)
      end
    end
  end

  defp import_email(account, message_id) do
    with {:ok, gmail_message} <- Gmail.get_message(account.id, message_id),
         {:ok, email_data} <- extract_email_data(gmail_message),
         {:ok, category, summary, urls} <- classify_email(account.user_id, email_data),
         {:ok, _email} <- save_email(account, category, email_data, message_id, summary, urls),
         {:ok, _} <- queue_archive(account.id, message_id) do
      :ok
    else
      {:error, reason} ->
        {:error, "Import failed: #{inspect(reason)}"}
    end
  end

  defp extract_email_data(%{"payload" => payload, "snippet" => snippet, "id" => id}) do
    subject = get_header(payload, "Subject")
    from = get_header(payload, "From")
    body_text = extract_body_text(payload)
    body_html = extract_body_html(payload)

    {:ok,
     %{
       subject: subject,
       from: from,
       snippet: snippet,
       body_text: body_text,
       body_html: body_html,
       gmail_message_id: id
     }}
  end

  defp get_header(payload, name) do
    headers = Map.get(payload, "headers", [])
    Enum.find_value(headers, fn %{"name" => n, "value" => v} -> if n == name, do: v end) || ""
  end

  defp extract_body_text(payload) do
    case get_body_part(payload, "text/plain") do
      nil -> ""
      data -> Base.decode64!(data) |> String.trim()
    end
  end

  defp extract_body_html(payload) do
    case get_body_part(payload, "text/html") do
      nil -> ""
      data -> Base.decode64!(data) |> String.trim()
    end
  end

  defp get_body_part(payload, mime_type) do
    parts = Map.get(payload, "parts", [])

    part =
      Enum.find(parts, fn part ->
        Map.get(part, "mimeType") == mime_type
      end)

    case part do
      nil ->
        # Try top-level body
        if Map.get(payload, "mimeType") == mime_type do
          Map.get(payload, "body", %{}) |> Map.get("data")
        else
          nil
        end

      part ->
        Map.get(part, "body", %{}) |> Map.get("data")
    end
  end

  defp classify_email(user_id, email_data) do
    categories = Categories.list_user_categories(user_id)

    if Enum.empty?(categories) do
      {:error, "No categories defined"}
    else
      case LLM.classify_and_summarize(email_data, email_data.body_text, categories) do
        {:ok, %{category_id: category_id, summary: summary, unsubscribe_urls: urls}} ->
          category = Categories.get_category(category_id)
          {:ok, category, summary, urls}

        {:error, _reason} ->
          # Fallback to first category
          first_category = List.first(categories)
          {:ok, first_category, "Unable to generate summary", []}
      end
    end
  end

  defp save_email(account, category, email_data, message_id, summary, unsubscribe_urls) do
    Emails.create_email(%{
      account_id: account.id,
      category_id: category.id,
      gmail_message_id: message_id,
      subject: email_data.subject,
      from: email_data.from,
      snippet: email_data.snippet,
      summary: summary,
      body_text: email_data.body_text,
      body_html: email_data.body_html,
      unsubscribe_urls: unsubscribe_urls
    })
  end

  defp queue_archive(account_id, message_id) do
    %{account_id: account_id, message_id: message_id}
    |> ArchiveEmail.new()
    |> Oban.insert()

    {:ok, :queued}
  end
end
