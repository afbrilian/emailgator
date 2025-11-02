defmodule Emailgator.Jobs.Unsubscribe do
  @moduledoc """
  Attempts to unsubscribe from an email using HTTP or Playwright.
  """
  use Oban.Worker, queue: :unsubscribe, max_attempts: 2
  alias Emailgator.{Emails, Unsubscribe}

  use Tesla
  adapter(Tesla.Adapter.Finch, name: Emailgator.Finch)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_id" => email_id}}) do
    require Logger
    Logger.info("Unsubscribe: Starting unsubscribe job for email #{email_id}")

    case Emails.get_email(email_id) do
      nil ->
        Logger.error("Unsubscribe: Email #{email_id} not found")
        {:cancel, "Email not found"}

      email ->
        unsubscribe_urls = email.unsubscribe_urls || []

        # Step 1: Check if unsubscribe_urls exist
        # Step 2: If no, try extracting from body_html
        # Step 3: If URLs exist, continue with existing flow
        final_urls =
          if Enum.empty?(unsubscribe_urls) do
            Logger.info("Unsubscribe: No unsubscribe URLs in database, extracting from HTML")

            # Step 2: Try extracting from body_html
            html_urls = extract_unsubscribe_from_html(email.body_html || "")

            if Enum.empty?(html_urls) do
              Logger.warning(
                "Unsubscribe: Email #{email_id} has no unsubscribe URLs in database or HTML"
              )

              # Create attempt record even when no URLs found, so user knows why it failed
              case Unsubscribe.create_attempt(%{
                     email_id: email.id,
                     method: "none",
                     url: "",
                     status: "failed",
                     evidence: %{error: "No unsubscribe URLs found in email or HTML body"}
                   }) do
                {:ok, attempt} ->
                  Logger.info(
                    "Unsubscribe: Created attempt record #{attempt.id} for email with no URLs"
                  )

                {:error, changeset} ->
                  Logger.error(
                    "Unsubscribe: Failed to create attempt record: #{inspect(changeset.errors)}"
                  )
              end

              {:error, "No unsubscribe URLs found"}
            else
              Logger.info(
                "Unsubscribe: Found #{length(html_urls)} unsubscribe URL(s) in HTML body"
              )

              html_urls
            end
          else
            Logger.info(
              "Unsubscribe: Found #{length(unsubscribe_urls)} unsubscribe URL(s) for email #{email_id}"
            )

            unsubscribe_urls
          end

        # Step 3: If URLs exist, continue with existing flow
        case final_urls do
          {:error, _reason} = error ->
            error

          urls when is_list(urls) and length(urls) > 0 ->
            attempt_unsubscribe(email, urls)

          _ ->
            {:error, "No unsubscribe URLs to process"}
        end
    end
  end

  defp attempt_unsubscribe(email, [url | rest]) do
    require Logger
    Logger.info("Unsubscribe: Attempting to unsubscribe from #{url} for email #{email.id}")

    case try_http_unsubscribe(url) do
      {:ok, :success} ->
        Logger.info("Unsubscribe: HTTP unsubscribe successful for email #{email.id}")

        Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "http",
          url: url,
          status: "success",
          evidence: %{response: "unsubscribed"}
        })

        :ok

      {:error, :needs_playwright} ->
        Logger.info("Unsubscribe: HTTP method failed, trying Playwright for email #{email.id}")
        # Try Playwright sidecar
        case try_playwright_unsubscribe(url) do
          {:ok, evidence} ->
            Logger.info("Unsubscribe: Playwright unsubscribe successful for email #{email.id}")

            Unsubscribe.create_attempt(%{
              email_id: email.id,
              method: "playwright",
              url: url,
              status: "success",
              evidence: evidence
            })

            :ok

          {:error, reason} ->
            Logger.warning(
              "Unsubscribe: Playwright failed for email #{email.id}: #{inspect(reason)}"
            )

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

  defp extract_unsubscribe_from_html(html) when is_binary(html) and html != "" do
    require Logger

    # Extract all href URLs from anchor tags (handle both single and double quotes)
    href_pattern = ~r/href\s*=\s*["']([^"']+)["']/i

    urls =
      Regex.scan(href_pattern, html)
      |> Enum.map(fn [_, url] -> url end)
      # Decode HTML entities (basic ones)
      |> Enum.map(&decode_html_entities/1)
      |> Enum.map(&String.trim/1)
      |> Enum.filter(fn url ->
        # Filter for unsubscribe-related URLs
        url_lower = String.downcase(url)

        String.contains?(url_lower, [
          "unsubscribe",
          "opt-out",
          "optout",
          "opt_out",
          "manage.preferences",
          "email.preferences",
          "preference",
          "berhenti",
          "cancel.subscription",
          "remove.me"
        ]) or
          (String.starts_with?(url, "mailto:") and String.contains?(url_lower, "unsubscribe"))
      end)
      |> Enum.filter(fn url ->
        # Only keep http/https/mailto URLs (filter out javascript:, data:, etc.)
        String.starts_with?(url, "http://") or
          String.starts_with?(url, "https://") or
          String.starts_with?(url, "mailto:")
      end)
      |> Enum.uniq()

    Logger.info("Unsubscribe: Extracted #{length(urls)} unsubscribe URL(s) from HTML")
    urls
  end

  defp extract_unsubscribe_from_html(_), do: []

  # Basic HTML entity decoding
  defp decode_html_entities(url) do
    url
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&nbsp;", " ")
  end

  defp try_http_unsubscribe(url) do
    require Logger

    Logger.info("Unsubscribe: Attempting HTTP GET to #{url}")

    # Use Task.async/yield with timeout to prevent hanging
    task =
      Task.async(fn ->
        try do
          # Use Finch directly with the named instance
          request = Finch.build(:get, url)
          Finch.request(request, Emailgator.Finch, receive_timeout: 15_000)
        rescue
          e ->
            Logger.error("Unsubscribe: Exception in HTTP request: #{inspect(e)}")
            {:error, inspect(e)}
        catch
          :exit, reason ->
            Logger.error("Unsubscribe: Task exited: #{inspect(reason)}")
            {:error, inspect(reason)}
        end
      end)

    case Task.yield(task, 20_000) || Task.shutdown(task) do
      {:ok, {:ok, %Finch.Response{status: status, body: body}}} ->
        handle_finch_response(status, body)

      {:ok, {:error, reason}} ->
        Logger.error("Unsubscribe: Finch request error: #{inspect(reason)}")
        {:error, inspect(reason)}

      {:ok, other} ->
        Logger.error("Unsubscribe: Unexpected Finch response: #{inspect(other)}")
        {:error, "Unexpected response"}

      nil ->
        Logger.warning("Unsubscribe: HTTP request timed out after 20s")
        {:error, "Request timeout"}

      {:exit, reason} ->
        Logger.error("Unsubscribe: HTTP request failed: #{inspect(reason)}")
        {:error, "Request failed"}
    end
  end

  defp handle_finch_response(status, _body) when status in [204, 302] do
    require Logger

    case status do
      204 ->
        Logger.info("Unsubscribe: HTTP 204 - Success (No Content)")
        {:ok, :success}

      302 ->
        Logger.info("Unsubscribe: HTTP 302 - Success (Redirect)")
        {:ok, :success}
    end
  end

  defp handle_finch_response(200, body) do
    require Logger

    # 200 OK - need to check response body to determine success
    body_str = if is_binary(body), do: String.downcase(body), else: ""

    # Check for success indicators in response
    success_indicators = [
      "unsubscribed",
      "successfully unsubscribed",
      "opt-out successful",
      "preference updated",
      "subscription cancelled",
      "you have been unsubscribed",
      "unsubscribe successful"
    ]

    is_success = Enum.any?(success_indicators, &String.contains?(body_str, &1))

    # Check if response is a form (needs Playwright)
    has_form =
      String.contains?(body_str, ["<form", "<input", "method=\"post\"", "method='post'"])

    has_checkbox = String.contains?(body_str, ["<input type=\"checkbox\"", "type='checkbox'"])

    cond do
      is_success ->
        Logger.info("Unsubscribe: HTTP 200 - Success confirmed from response body")
        {:ok, :success}

      has_form or has_checkbox ->
        Logger.info("Unsubscribe: HTTP 200 - Response contains form/checkbox, needs Playwright")

        {:error, :needs_playwright}

      true ->
        # 200 OK but unclear - assume success for now (GET on unsubscribe link usually works)
        Logger.info("Unsubscribe: HTTP 200 - Assuming success (no form detected)")
        {:ok, :success}
    end
  end

  defp handle_finch_response(405, _body) do
    require Logger
    Logger.info("Unsubscribe: HTTP 405 - Method not allowed, requires form (Playwright)")
    {:error, :needs_playwright}
  end

  defp handle_finch_response(400, _body) do
    require Logger
    Logger.info("Unsubscribe: HTTP 400 - Bad request, may need form (Playwright)")
    {:error, :needs_playwright}
  end

  defp handle_finch_response(status, _body) do
    require Logger
    Logger.warning("Unsubscribe: HTTP #{status} - Unexpected status code")
    {:error, "HTTP #{status}"}
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
         body: %{
           "ok" => true,
           "status" => status,
           "screenshot_b64" => screenshot,
           "actions" => actions
         }
       }} ->
        evidence = %{
          status: status,
          screenshot: screenshot,
          actions: actions || []
        }

        {:ok, evidence}

      {:ok, %Tesla.Env{status: 200, body: body}} when is_map(body) ->
        # Handle older response format or responses without all fields
        status = Map.get(body, "status", "unknown")
        screenshot = Map.get(body, "screenshot_b64", "")
        actions = Map.get(body, "actions", [])

        evidence = %{
          status: status,
          screenshot: screenshot,
          actions: actions
        }

        {:ok, evidence}

      {:ok, %Tesla.Env{body: body}} ->
        {:error, inspect(body)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
