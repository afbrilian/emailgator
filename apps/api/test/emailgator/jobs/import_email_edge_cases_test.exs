defmodule Emailgator.Jobs.ImportEmailEdgeCasesTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.Jobs.ImportEmail
  alias Emailgator.{Accounts, Emails, LLM, Categories}

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    Application.put_env(:tesla, Emailgator.Gmail, adapter: Tesla.Mock)
    Application.put_env(:tesla, Emailgator.LLM, adapter: Tesla.Mock)

    Application.put_env(:emailgator_api, :openai,
      api_key: "test-key",
      base_url: "http://localhost:4003"
    )

    on_exit(fn ->
      Application.delete_env(:tesla, Emailgator.Gmail)
      Application.delete_env(:tesla, Emailgator.LLM)
    end)

    :ok
  end

  describe "extract_email_data edge cases" do
    test "handles nested parts for body text extraction" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "parts" => [
            %{
              "mimeType" => "text/plain",
              "body" => %{"data" => Base.url_encode64("Plain text body")}
            },
            %{
              "mimeType" => "text/html",
              "body" => %{"data" => Base.url_encode64("<p>HTML body</p>")}
            }
          ],
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"}
          ]
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      assert email.body_text == "Plain text body"
      assert email.body_html == "<p>HTML body</p>"
    end

    test "handles top-level body when mimeType matches" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "mimeType" => "text/plain",
          "body" => %{"data" => Base.url_encode64("Direct text body")},
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"}
          ]
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      assert email.body_text == "Direct text body"
    end

    test "handles Base64 fallback when url_decode64 fails" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      # Use standard Base64 encoding (not url-safe)
      encoded_body = Base.encode64("Test body text")

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "mimeType" => "text/plain",
          "body" => %{"data" => encoded_body},
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"}
          ]
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      assert email.body_text == "Test body text"
    end

    test "handles empty body parts gracefully" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "parts" => [
            %{
              "mimeType" => "text/plain",
              "body" => %{"data" => ""}
            }
          ],
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"}
          ]
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      # Empty string may be stored as nil in database
      assert email.body_text in [nil, ""]
    end

    test "handles unsubscribe URLs in nested parts" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"},
            %{"name" => "List-Unsubscribe", "value" => "<https://example.com/unsub1>"}
          ],
          "parts" => [
            %{
              "mimeType" => "text/plain",
              "body" => %{"data" => Base.url_encode64("Body")},
              "headers" => [
                %{"name" => "List-Unsubscribe", "value" => "<https://example.com/unsub2>"}
              ]
            }
          ]
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      # Should extract URLs from both top-level and nested headers
      assert "https://example.com/unsub1" in email.unsubscribe_urls
      assert "https://example.com/unsub2" in email.unsubscribe_urls
    end

    test "handles List-Unsubscribe-Post header" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"},
            %{"name" => "List-Unsubscribe-Post", "value" => "<https://example.com/unsub-post>"}
          ],
          "mimeType" => "text/plain",
          "body" => %{"data" => Base.url_encode64("Body")}
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      assert "https://example.com/unsub-post" in email.unsubscribe_urls
    end

    test "handles mailto unsubscribe URLs" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"},
            %{
              "name" => "List-Unsubscribe",
              "value" => "<mailto:unsubscribe@example.com?subject=unsubscribe>"
            }
          ],
          "mimeType" => "text/plain",
          "body" => %{"data" => Base.url_encode64("Body")}
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      assert "mailto:unsubscribe@example.com?subject=unsubscribe" in email.unsubscribe_urls
    end

    test "handles multiple URLs in List-Unsubscribe header" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      category = create_category(user)

      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet",
        "payload" => %{
          "headers" => [
            %{"name" => "Subject", "value" => "Test"},
            %{"name" => "From", "value" => "test@example.com"},
            %{
              "name" => "List-Unsubscribe",
              "value" =>
                "<https://example.com/unsub1>, <https://example.com/unsub2>, <mailto:unsub@example.com>"
            }
          ],
          "mimeType" => "text/plain",
          "body" => %{"data" => Base.url_encode64("Body")}
        }
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)

        %{method: :post} ->
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" =>
                    Jason.encode!(%{
                      "category_id" => category.id,
                      "summary" => "Test summary",
                      "unsubscribe_urls" => []
                    })
                }
              }
            ]
          })
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert :ok = result

      email = Emails.get_email_by_gmail_id(account.id, "msg123")
      urls = email.unsubscribe_urls
      assert "https://example.com/unsub1" in urls
      assert "https://example.com/unsub2" in urls
      assert "mailto:unsub@example.com" in urls
    end

    test "handles extraction error with rescue" do
      user = create_user()

      account =
        create_account(user, %{
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      # Message that will cause an error during extraction (missing required keys)
      gmail_message = %{
        "id" => "msg123",
        "snippet" => "Test snippet"
        # Missing payload
      }

      mock(fn
        %{method: :get} ->
          mock_json(gmail_message)
      end)

      result =
        ImportEmail.perform(%Oban.Job{
          args: %{"account_id" => account.id, "message_id" => "msg123"}
        })

      assert {:error, "Import failed at extraction: " <> _reason} = result
    end
  end
end
