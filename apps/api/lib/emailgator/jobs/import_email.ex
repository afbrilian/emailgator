defmodule Emailgator.Jobs.ImportEmail do
  @moduledoc """
  Imports a single email: fetches from Gmail, classifies with LLM, saves to DB, then archives.
  """
  use Oban.Worker, queue: :import, max_attempts: 3
  alias Emailgator.{Accounts, Categories, Emails, Gmail, LLM, Jobs.ArchiveEmail}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"account_id" => account_id, "message_id" => message_id}}) do
    Logger.info("ImportEmail: Starting import for message #{message_id}, account #{account_id}")

    account = Accounts.get_account(account_id)

    if is_nil(account) do
      Logger.error("ImportEmail: Account #{account_id} not found")
      {:cancel, "Account not found"}
    else
      # Check if email already imported
      if Emails.get_email_by_gmail_id(account_id, message_id) do
        Logger.info("ImportEmail: Message #{message_id} already imported, skipping")
        :ok
      else
        Logger.info("ImportEmail: Importing new message #{message_id}")
        import_email(account, message_id)
      end
    end
  end

  defp import_email(account, message_id) do
    Logger.info("ImportEmail: Step 1 - Fetching message from Gmail API")

    case Gmail.get_message(account.id, message_id) do
      {:ok, gmail_message} ->
        Logger.info("ImportEmail: Step 2 - Extracting email data")

        case extract_email_data(gmail_message) do
          {:ok, email_data} ->
            Logger.info("ImportEmail: Step 3 - Classifying email with LLM")

            case classify_email(account.user_id, email_data) do
              {:ok, category, summary, urls} ->
                Logger.info("ImportEmail: Step 4 - Saving email to database")

                case save_email(account, category, email_data, message_id, summary, urls) do
                  {:ok, _email} ->
                    Logger.info("ImportEmail: Step 5 - Queuing archive job")

                    case queue_archive(account.id, message_id) do
                      {:ok, _} ->
                        Logger.info("ImportEmail: Successfully imported message #{message_id}")
                        :ok

                      {:error, reason} ->
                        Logger.warning(
                          "ImportEmail: Import succeeded but archive queue failed: #{inspect(reason)}"
                        )

                        # Still return :ok since email was imported
                        :ok
                    end

                  {:error, reason} ->
                    Logger.error("ImportEmail: Failed to save email: #{inspect(reason)}")
                    {:error, "Import failed at save: #{inspect(reason)}"}
                end

              {:error, {:rate_limit, _}} ->
                Logger.warning("ImportEmail: Rate limited, snoozing for 20 seconds")
                {:snooze, 20}

              {:error, reason} ->
                Logger.error("ImportEmail: Failed to classify email: #{inspect(reason)}")
                {:error, "Import failed at classification: #{inspect(reason)}"}
            end

          {:error, reason} ->
            Logger.error("ImportEmail: Failed to extract email data: #{inspect(reason)}")
            {:error, "Import failed at extraction: #{inspect(reason)}"}
        end

      {:error, reason} ->
        Logger.error("ImportEmail: Failed to fetch message from Gmail: #{inspect(reason)}")
        {:error, "Import failed at Gmail fetch: #{inspect(reason)}"}
    end
  end

  defp extract_email_data(%{"payload" => payload, "snippet" => snippet, "id" => id}) do
    try do
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
    rescue
      e ->
        Logger.error("ImportEmail: Failed to extract email data: #{inspect(e)}")
        {:error, "Failed to extract email data: #{inspect(e)}"}
    end
  end

  defp extract_email_data(_invalid_message) do
    {:error, "Invalid message format"}
  end

  defp get_header(payload, name) do
    headers = Map.get(payload, "headers", [])
    Enum.find_value(headers, fn %{"name" => n, "value" => v} -> if n == name, do: v end) || ""
  end

  defp extract_body_text(payload) do
    case get_body_part(payload, "text/plain") do
      nil ->
        ""

      "" ->
        ""

      data ->
        # Gmail API uses Base64url encoding (RFC 4648 §5)
        case Base.url_decode64(data) do
          {:ok, decoded} ->
            String.trim(decoded)

          :error ->
            # Fallback to standard Base64 if url_decode fails
            try do
              Base.decode64!(data) |> String.trim()
            rescue
              _e -> ""
            end
        end
    end
  end

  defp extract_body_html(payload) do
    case get_body_part(payload, "text/html") do
      nil ->
        ""

      "" ->
        ""

      data ->
        # Gmail API uses Base64url encoding (RFC 4648 §5)
        case Base.url_decode64(data) do
          {:ok, decoded} ->
            String.trim(decoded)

          :error ->
            # Fallback to standard Base64 if url_decode fails
            try do
              Base.decode64!(data) |> String.trim()
            rescue
              _e -> ""
            end
        end
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

        {:error, {:rate_limit, _body}} ->
          # Rate limit error - return special error to trigger retry with backoff
          Logger.warning("ImportEmail: OpenAI rate limit hit, job will retry with backoff")
          {:error, {:rate_limit, "OpenAI rate limit exceeded"}}

        {:error, _reason} ->
          # Fallback to first category for other errors
          Logger.warning("ImportEmail: LLM classification failed, using fallback category")
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
    case %{account_id: account_id, message_id: message_id}
         |> ArchiveEmail.new()
         |> Oban.insert() do
      {:ok, _job} ->
        {:ok, :queued}

      {:error, reason} ->
        Logger.warning("ImportEmail: Failed to queue archive job: #{inspect(reason)}")
        {:error, "Failed to queue archive: #{inspect(reason)}"}
    end
  end
end
