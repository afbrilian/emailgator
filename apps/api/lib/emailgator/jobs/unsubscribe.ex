defmodule Emailgator.Jobs.Unsubscribe do
  @moduledoc """
  Attempts to unsubscribe from an email using the Playwright sidecar service.
  The sidecar handles both simple unsubscribe links and complex forms.
  """
  use Oban.Worker, queue: :unsubscribe, max_attempts: 2
  alias Emailgator.{Emails, Unsubscribe}

  require Logger

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

    Logger.info(
      "Unsubscribe: Attempting to unsubscribe from #{url} for email #{email.id} (using sidecar)"
    )

    # Always use Playwright sidecar for all unsubscribe attempts
    # This ensures we can handle both simple links and forms, and verify actual success
    case try_playwright_unsubscribe(url) do
      {:ok, evidence} ->
        Logger.info("Unsubscribe: Sidecar unsubscribe successful for email #{email.id}")

        Unsubscribe.create_attempt(%{
          email_id: email.id,
          method: "playwright",
          url: url,
          status: "success",
          evidence: evidence
        })

        :ok

      {:error, reason} ->
        Logger.warning("Unsubscribe: Sidecar failed for email #{email.id}: #{inspect(reason)}")

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
          "remove.me",
          # Indonesian keywords for subscription management
          # subscription
          "langganan",
          # subscription settings
          "pengaturan.langganan",
          # change settings
          "ubah.pengaturan",
          # manage subscription
          "kelola.langganan",
          # stop subscription
          "hentikan.langganan"
        ]) or
          (String.starts_with?(url, "mailto:") and
             String.contains?(url_lower, ["unsubscribe", "berhenti", "langganan"]))
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

  defp try_playwright_unsubscribe(url) do
    require Logger

    sidecar_config = Application.get_env(:emailgator_api, :sidecar)

    if is_nil(sidecar_config) do
      Logger.error("Unsubscribe: Sidecar configuration not found")
      {:error, "Sidecar configuration missing"}
    else
      sidecar_url = Keyword.get(sidecar_config, :url)
      token = Keyword.get(sidecar_config, :token)

      if is_nil(sidecar_url) or is_nil(token) do
        Logger.error(
          "Unsubscribe: Sidecar URL or token missing. URL: #{inspect(sidecar_url)}, Token: #{if token, do: "[REDACTED]", else: "nil"}"
        )

        {:error, "Sidecar configuration incomplete"}
      else
        Logger.info("Unsubscribe: Calling sidecar at #{sidecar_url}/run for URL: #{url}")

        Logger.info(
          "Unsubscribe: Token length: #{String.length(to_string(token))}, first 4 chars: #{String.slice(to_string(token), 0..3)}..."
        )

        # Use Task with timeout to prevent hanging requests (90s timeout for Playwright)
        task =
          Task.async(fn ->
            try do
              # Use Finch directly with explicit timeout (90s for sidecar operations)
              body_json = Jason.encode!(%{url: url})

              request =
                Finch.build(
                  :post,
                  "#{sidecar_url}/run",
                  [{"content-type", "application/json"}, {"x-internal", token}],
                  body_json
                )

              result = Finch.request(request, Emailgator.Finch, receive_timeout: 90_000)

              # Convert Finch response to Tesla response format for compatibility
              case result do
                {:ok, %Finch.Response{status: status, body: body}} ->
                  # Parse JSON body
                  body_map =
                    case Jason.decode(body) do
                      {:ok, decoded} -> decoded
                      {:error, _} -> body
                    end

                  # Convert to Tesla.Env format
                  tesla_env = %Tesla.Env{
                    status: status,
                    body: body_map
                  }

                  {:ok, tesla_env}

                {:error, reason} ->
                  {:error, reason}
              end
            rescue
              e ->
                Logger.error("Unsubscribe: Exception in Task: #{inspect(e)}")
                {:error, inspect(e)}
            catch
              :exit, reason ->
                Logger.error("Unsubscribe: Task exited: #{inspect(reason)}")
                {:error, inspect(reason)}
            end
          end)

        Logger.debug("Unsubscribe: Waiting for sidecar response with 90s timeout...")

        result =
          case Task.yield(task, 90_000) || Task.shutdown(task) do
            {:ok,
             {:ok,
              %Tesla.Env{
                status: 200,
                body: %{
                  "ok" => true,
                  "status" => status,
                  "screenshot_b64" => screenshot,
                  "actions" => actions
                }
              }}} ->
              Logger.info("Unsubscribe: Sidecar returned success with status: #{status}")

              evidence = %{
                status: status,
                screenshot: screenshot,
                actions: actions || []
              }

              {:ok, evidence}

            {:ok, {:ok, %Tesla.Env{status: 200, body: body}}} when is_map(body) ->
              # Handle older response format or responses without all fields
              status = Map.get(body, "status", "unknown")
              screenshot = Map.get(body, "screenshot_b64", "")
              actions = Map.get(body, "actions", [])

              Logger.info(
                "Unsubscribe: Sidecar returned success (legacy format) with status: #{status}"
              )

              evidence = %{
                status: status,
                screenshot: screenshot,
                actions: actions
              }

              {:ok, evidence}

            {:ok, {:ok, %Tesla.Env{status: status, body: body}}} ->
              Logger.error(
                "Unsubscribe: Sidecar returned error status #{status}: #{inspect(body)}"
              )

              {:error, "Sidecar returned status #{status}: #{inspect(body)}"}

            {:ok, {:error, reason}} ->
              Logger.error("Unsubscribe: Sidecar request error: #{inspect(reason)}")
              {:error, inspect(reason)}

            nil ->
              Logger.error("Unsubscribe: Sidecar request timed out after 90 seconds")

              {:error,
               "Sidecar request timed out - is the sidecar running? (Check sidecar logs for progress)"}

            {:exit, reason} ->
              Logger.error("Unsubscribe: Task exited: #{inspect(reason)}")
              {:error, "Request task failed"}
          end

        Logger.debug("Unsubscribe: Sidecar task result: #{inspect(result)}")
        result
      end
    end
  end
end
