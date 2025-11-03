defmodule Emailgator.LLMTest do
  use Emailgator.DataCase

  alias Emailgator.{LLM, Categories}
  import Tesla.Mock

  setup do
    # Set up OpenAI API key for testing
    Application.put_env(:emailgator_api, :openai,
      api_key: "test-key",
      base_url: "http://localhost:4003"
    )

    # Configure Tesla to use Mock adapter for LLM in tests
    Application.put_env(:tesla, Emailgator.LLM, adapter: Tesla.Mock)

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.LLM)
    end)

    :ok
  end

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  describe "classify_and_summarize/3" do
    test "successfully classifies and summarizes email" do
      user = create_user()
      category1 = create_category(user, %{name: "Work", description: "Work emails"})
      category2 = create_category(user, %{name: "Personal", description: "Personal emails"})

      email_meta = %{
        subject: "Meeting Tomorrow",
        from: "boss@company.com"
      }

      body_text = "We need to discuss the project tomorrow at 2 PM."

      mock_response = %{
        "category_id" => category1.id,
        "summary" => "Meeting reminder for tomorrow at 2 PM",
        "unsubscribe_urls" => []
      }

      mock(fn
        %{method: :post, url: url} ->
          if String.contains?(url, "/chat/completions") do
            mock_json(%{
              "choices" => [
                %{
                  "message" => %{
                    "content" => Jason.encode!(mock_response)
                  }
                }
              ]
            })
          else
            %Tesla.Env{status: 404}
          end
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category1, category2])

      assert {:ok, %{category_id: cat_id, summary: summary, unsubscribe_urls: urls}} = result
      assert cat_id == category1.id
      assert summary == "Meeting reminder for tomorrow at 2 PM"
      assert urls == []
    end

    test "extracts unsubscribe URLs from email" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Newsletter", from: "news@example.com"}
      body_text = "Check out our newsletter. Unsubscribe here: https://example.com/unsubscribe"

      mock_response = %{
        "category_id" => category.id,
        "summary" => "Newsletter email",
        "unsubscribe_urls" => ["https://example.com/unsubscribe"]
      }

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(mock_response)
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:ok, %{unsubscribe_urls: urls}} = result
      assert "https://example.com/unsubscribe" in urls
    end

    test "falls back to first category when category_id is invalid" do
      user = create_user()
      category1 = create_category(user, %{name: "Default"})
      category2 = create_category(user, %{name: "Other"})

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      # Return invalid category ID
      mock_response = %{
        # Invalid ID
        "category_id" => Ecto.UUID.generate(),
        "summary" => "Test summary",
        "unsubscribe_urls" => []
      }

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(mock_response)
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category1, category2])

      assert {:ok, %{category_id: cat_id}} = result
      # Should fall back to first category
      assert cat_id == category1.id
    end

    test "handles rate limit errors" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock(fn
        %{method: :post} ->
          %Tesla.Env{
            status: 429,
            body: %{"error" => %{"message" => "Rate limit exceeded"}}
          }
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:error, {:rate_limit, _body}} = result
    end

    test "returns error when API key is missing" do
      Application.put_env(:emailgator_api, :openai,
        api_key: nil,
        base_url: "http://localhost:4003"
      )

      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:error, "OpenAI API key not configured"} = result
    end

    test "handles API errors" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock(fn
        %{method: :post} ->
          %Tesla.Env{
            status: 500,
            body: %{"error" => %{"message" => "Internal server error"}}
          }
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:error, _reason} = result
    end

    test "handles invalid JSON response" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => "Invalid JSON response"
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:error, _reason} = result
    end

    test "handles empty API key" do
      Application.put_env(:emailgator_api, :openai,
        api_key: "",
        base_url: "http://localhost:4003"
      )

      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:error, "OpenAI API key not configured"} = result
    end

    test "handles response with missing category_id" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock_response = %{
        "summary" => "Test summary",
        "unsubscribe_urls" => []
        # Missing category_id
      }

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(mock_response)
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      # parse_response requires category_id, so this will return an error
      assert {:error, "Invalid response format: " <> _reason} = result
    end

    test "handles response with missing summary" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock_response = %{
        "category_id" => category.id,
        "unsubscribe_urls" => []
        # Missing summary
      }

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(mock_response)
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      # parse_response requires summary, so this will return an error
      assert {:error, "Invalid response format: " <> _reason} = result
    end

    test "handles response with missing unsubscribe_urls" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock_response = %{
        "category_id" => category.id,
        "summary" => "Test summary"
        # Missing unsubscribe_urls
      }

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(mock_response)
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      # parse_response requires unsubscribe_urls, so this will return an error
      assert {:error, "Invalid response format: " <> _reason} = result
    end

    test "handles request error (network failure)" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock(fn
        %{method: :post} ->
          {:error, :econnrefused}
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      assert {:error, :econnrefused} = result
    end

    test "handles response with empty choices array" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test email"

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => []
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])

      # Should handle empty choices - parse_response will try to extract from empty
      # This tests the error path in parse_response
      assert {:error, _reason} = result
    end
  end

  describe "format_categories/1" do
    test "formats categories correctly" do
      user = create_user()
      category1 = create_category(user, %{name: "Work", description: "Work emails"})
      category2 = create_category(user, %{name: "Personal", description: nil})

      # format_categories is private, test through classify_and_summarize
      # The prompt will include formatted categories
      email_meta = %{subject: "Test", from: "test@example.com"}
      body_text = "Test"

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category1.id,
                      "summary" => "Test",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category1, category2])
      assert {:ok, %{category_id: _}} = result
    end
  end

  describe "build_prompt/3 edge cases" do
    test "handles email with very long body text" do
      user = create_user()
      category = create_category(user)

      email_meta = %{subject: "Test", from: "test@example.com"}
      # Body longer than 4000 chars (truncated in prompt)
      body_text = String.duplicate("a", 5000)

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])
      assert {:ok, %{category_id: _}} = result
    end

    test "handles email with missing subject" do
      user = create_user()
      category = create_category(user)

      email_meta = %{from: "test@example.com"}
      body_text = "Test"

      mock(fn
        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result = LLM.classify_and_summarize(email_meta, body_text, [category])
      assert {:ok, %{category_id: _}} = result
    end
  end
end
