defmodule Emailgator.LLM do
  @moduledoc """
  LLM adapter for OpenAI (GPT-4o-mini).
  """
  use Tesla
  alias Emailgator.Categories.Category

  plug(Tesla.Middleware.BaseUrl, Application.get_env(:emailgator_api, :openai)[:base_url])
  plug(Tesla.Middleware.JSON)

  @doc """
  Classify email into a category and generate a summary.
  Returns {:ok, %{category_id: id, summary: text, unsubscribe_urls: [urls]}}
  """
  def classify_and_summarize(email_meta, body_text, categories) do
    categories_json = format_categories(categories)
    prompt = build_prompt(email_meta, body_text, categories_json)

    case call_openai(prompt) do
      {:ok, response} ->
        parse_response(response, categories)

      {:error, reason} ->
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

    If no category matches well, choose the first category. Extract all unsubscribe URLs from headers and body.
    """
  end

  defp call_openai(prompt) do
    api_key = Application.get_env(:emailgator_api, :openai)[:api_key]

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

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

    case post("/chat/completions", body, headers: headers) do
      {:ok,
       %Tesla.Env{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => content}} | _]}
       }} ->
        {:ok, content}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, "OpenAI API error #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
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
        {:error, "Failed to parse JSON: #{reason}"}
    end
  end
end
