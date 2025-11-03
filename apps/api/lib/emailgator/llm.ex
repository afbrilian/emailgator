defmodule Emailgator.LLM do
  @moduledoc """
  LLM adapter for OpenAI (GPT-4o-mini).
  """
  use Tesla
  alias Emailgator.Categories.Category

  require Logger

  adapter(Tesla.Adapter.Finch, name: Emailgator.Finch)

  plug(Tesla.Middleware.BaseUrl, Application.get_env(:emailgator_api, :openai)[:base_url])
  plug(Tesla.Middleware.JSON)

  @doc """
  Classify email into a category and generate a summary.
  Returns {:ok, %{category_id: id, summary: text, unsubscribe_urls: [urls]}}
  """
  def classify_and_summarize(email_meta, body_text, categories) do
    Logger.info(
      "LLM.classify_and_summarize: Starting classification for email from #{Map.get(email_meta, :from, "unknown")}"
    )

    categories_json = format_categories(categories)
    prompt = build_prompt(email_meta, body_text, categories_json)

    case call_openai(prompt) do
      {:ok, response} ->
        Logger.info("LLM.classify_and_summarize: Received response from OpenAI, parsing...")
        result = parse_response(response, categories)

        case result do
          {:ok, %{category_id: cat_id}} ->
            Logger.info(
              "LLM.classify_and_summarize: Successfully classified into category #{cat_id}"
            )

          _ ->
            Logger.warning(
              "LLM.classify_and_summarize: Classification returned error: #{inspect(result)}"
            )
        end

        result

      {:error, reason} ->
        Logger.error("LLM.classify_and_summarize: OpenAI API error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers

  defp format_categories(categories) do
    categories
    |> Enum.map(fn %Category{id: id, name: name, description: desc} ->
      %{id: id, name: name, description: desc || ""}
    end)
    |> Jason.encode!()
  end

  defp build_prompt(email_meta, body_text, categories_json) do
    subject = Map.get(email_meta, :subject, "")
    from = Map.get(email_meta, :from, "")

    """
    You are an email classification assistant. Analyze the following email and classify it into ONE of the provided categories. Also provide a concise summary.

    Categories:
    #{categories_json}

    Email:
    Subject: #{subject}
    From: #{from}
    Body: #{String.slice(body_text, 0, 4000)}

    Return a valid JSON object with this exact structure:
    {
      "category_id": "<uuid-of-category>",
      "summary": "<brief summary in 2-3 sentences>",
      "unsubscribe_urls": ["<url1>", "<url2>"]
    }

    If no category matches well, choose the first category. Extract ALL unsubscribe URLs from the email body text and HTML links. Look for patterns like:
    - Links containing "unsubscribe", "opt-out", "opt out", "manage preferences", "email preferences", "berhenti berlangganan"
    - mailto: links with subject containing "unsubscribe"
    - URLs in text that clearly indicate unsubscribing

    Return an empty array [] if no unsubscribe URLs are found. Only include actual URLs (http://, https://, or mailto:).
    """
  end

  defp call_openai(prompt) do
    api_key = Application.get_env(:emailgator_api, :openai)[:api_key]

    if is_nil(api_key) or api_key == "" do
      Logger.error("LLM.call_openai: OpenAI API key is missing")
      {:error, "OpenAI API key not configured"}
    else
      headers = [
        {"Authorization", "Bearer #{api_key}"}
      ]

      # Tesla.Middleware.JSON expects atom keys and will encode to JSON automatically
      body = %{
        model: "gpt-4o-mini",
        messages: [
          %{
            role: "system",
            content: "You are a helpful email assistant. Always respond with valid JSON only."
          },
          %{
            role: "user",
            content: prompt
          }
        ],
        response_format: %{type: "json_object"},
        temperature: 0.3
      }

      # Encode body manually to ensure it's JSON
      body_json = Jason.encode!(body)
      Logger.debug("LLM.call_openai: Request body encoded, length: #{byte_size(body_json)} bytes")

      Logger.info(
        "LLM.call_openai: Making request to OpenAI API (timeout: 60s), model: gpt-4o-mini"
      )

      # Use Task with timeout to prevent hanging requests
      task =
        Task.async(fn ->
          try do
            # Send JSON string directly with proper content-type
            result =
              post("/chat/completions", body_json,
                headers: [{"Content-Type", "application/json"} | headers]
              )

            Logger.debug("LLM.call_openai: Request completed in Task")
            result
          rescue
            e ->
              Logger.error("LLM.call_openai: Exception in Task: #{inspect(e)}")
              {:error, inspect(e)}
          catch
            :exit, reason ->
              Logger.error("LLM.call_openai: Task exited: #{inspect(reason)}")
              {:error, inspect(reason)}
          end
        end)

      Logger.debug("LLM.call_openai: Waiting for Task with 60s timeout...")

      result =
        case Task.yield(task, 60_000) || Task.shutdown(task) do
          {:ok,
           {:ok,
            %Tesla.Env{
              status: 200,
              body: %{"choices" => [%{"message" => %{"content" => content}} | _]}
            }}} ->
            Logger.info("LLM.call_openai: Successfully received response from OpenAI")
            {:ok, content}

          {:ok, {:ok, %Tesla.Env{status: status, body: body}}} ->
            # Handle rate limits (429)
            if status == 429 do
              Logger.warning("LLM.call_openai: Rate limit exceeded, will retry with backoff")
              # Return a special error that triggers retry with backoff
              {:error, {:rate_limit, body}}
            else
              Logger.error("LLM.call_openai: OpenAI API error #{status}: #{inspect(body)}")
              {:error, "OpenAI API error #{status}: #{inspect(body)}"}
            end

          {:ok, {:error, reason}} ->
            Logger.error("LLM.call_openai: Request error: #{inspect(reason)}")
            {:error, reason}

          nil ->
            Logger.error("LLM.call_openai: Request timed out after 60 seconds")
            {:error, "Request timed out"}

          {:exit, reason} ->
            Logger.error("LLM.call_openai: Task exited: #{inspect(reason)}")
            {:error, "Request task failed"}
        end

      Logger.debug("LLM.call_openai: Task result: #{inspect(result)}")
      result
    end
  end

  defp parse_response(json_string, categories) do
    case Jason.decode(json_string) do
      {:ok, %{"category_id" => category_id, "summary" => summary, "unsubscribe_urls" => urls}} ->
        # Validate category_id exists
        category_ids = Enum.map(categories, fn c -> c.id end)

        if category_id in category_ids do
          {:ok, %{category_id: category_id, summary: summary, unsubscribe_urls: urls || []}}
        else
          # Fallback to first category
          first_category = List.first(categories)

          {:ok,
           %{
             category_id: first_category.id,
             summary: summary || "No summary available",
             unsubscribe_urls: urls || []
           }}
        end

      {:ok, data} ->
        {:error, "Invalid response format: #{inspect(data)}"}

      {:error, reason} ->
        {:error, "Failed to parse JSON: #{inspect(reason)}"}
    end
  end
end
