defmodule Emailgator.Jobs.Unsubscribe do
  @moduledoc """
  Attempts to unsubscribe from an email using HTTP or Playwright.
  """
  use Oban.Worker, queue: :unsubscribe, max_attempts: 2
  alias Emailgator.{Emails, Unsubscribe}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_id" => email_id}}) do
    case Emails.get_email(email_id) do
      nil ->
        {:cancel, "Email not found"}

      email ->
        unsubscribe_urls = email.unsubscribe_urls || []

        if Enum.empty?(unsubscribe_urls) do
          {:error, "No unsubscribe URLs found"}
        else
          attempt_unsubscribe(email, unsubscribe_urls)
        end
    end
  end

  defp attempt_unsubscribe(email, [url | rest]) do
    case try_http_unsubscribe(url) do
      {:ok, :success} ->
        Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "http",
          url: url,
          status: "success",
          evidence: %{response: "unsubscribed"}
        })

        :ok

      {:error, :needs_playwright} ->
        # Try Playwright sidecar
        case try_playwright_unsubscribe(url) do
          {:ok, evidence} ->
            Unsubscribe.create_attempt(%{
              email_id: email.id,
              method: "playwright",
              url: url,
              status: "success",
              evidence: evidence
            })

            :ok

          {:error, reason} ->
            # Try next URL if available
            if Enum.empty?(rest) do
              Unsubscribe.create_attempt(%{
                email_id: email.id,
                method: "playwright",
                url: url,
                status: "failed",
                evidence: %{error: inspect(reason)}
              })

              {:error, "All unsubscribe attempts failed"}
            else
              attempt_unsubscribe(email, rest)
            end
        end

      {:error, reason} ->
        if Enum.empty?(rest) do
          Unsubscribe.create_attempt(%{
            email_id: email.id,
            method: "http",
            url: url,
            status: "failed",
            evidence: %{error: inspect(reason)}
          })

          {:error, reason}
        else
          attempt_unsubscribe(email, rest)
        end
    end
  end

  defp attempt_unsubscribe(_email, []) do
    {:error, "No unsubscribe URLs to try"}
  end

  defp try_http_unsubscribe(url) do
    client =
      Tesla.client([
        Tesla.Middleware.FollowRedirects,
        {Tesla.Middleware.BaseUrl, url}
      ])

    case Tesla.get(client, "/") do
      {:ok, %Tesla.Env{status: status}} when status in [200, 302, 204] ->
        {:ok, :success}

      {:ok, %Tesla.Env{status: status}} ->
        # If it's a form, need Playwright
        if status == 405 or status == 400 do
          {:error, :needs_playwright}
        else
          {:error, "HTTP #{status}"}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp try_playwright_unsubscribe(url) do
    sidecar_url = Application.get_env(:emailgator_api, :sidecar)[:url]
    token = Application.get_env(:emailgator_api, :sidecar)[:token]

    client = Tesla.client([Tesla.Middleware.JSON])

    case Tesla.post(
           client,
           "#{sidecar_url}/run",
           %{url: url},
           headers: [{"x-internal", token}]
         ) do
      {:ok,
       %Tesla.Env{
         status: 200,
         body: %{"ok" => true, "status" => status, "screenshot_b64" => screenshot}
       }} ->
        {:ok, %{status: status, screenshot: screenshot}}

      {:ok, %Tesla.Env{body: body}} ->
        {:error, inspect(body)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
