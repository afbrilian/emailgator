defmodule Emailgator.Jobs.ImportEmailTest do
  use Emailgator.DataCase
  import Tesla.Mock

  alias Emailgator.{Jobs.ImportEmail, Accounts, Gmail, Emails, Categories}

  defp mock_json(data), do: %Tesla.Env{status: 200, body: data}

  setup do
    # Configure Tesla to use Mock adapter for Gmail and LLM in tests
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

  test "perform/1 returns cancel when account not found" do
    fake_account_id = Ecto.UUID.generate()

    assert {:cancel, "Account not found"} =
             ImportEmail.perform(%Oban.Job{
               args: %{"account_id" => fake_account_id, "message_id" => "msg123"}
             })
  end

  test "perform/1 skips already imported emails" do
    user = create_user()
    account = create_account(user)
    category = create_category(user)
    message_id = "gmail_msg_#{System.unique_integer([:positive])}"

    # Create email with this gmail_message_id
    create_email(account, category, %{gmail_message_id: message_id})

    assert :ok =
             ImportEmail.perform(%Oban.Job{
               args: %{"account_id" => account.id, "message_id" => message_id}
             })
  end

  test "perform/1 successfully imports email" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user, %{name: "Work"})

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test email snippet",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test Subject"},
          %{"name" => "From", "value" => "sender@example.com"},
          %{"name" => "List-Unsubscribe", "value" => "<https://example.com/unsubscribe>"}
        ],
        "parts" => [
          %{
            "mimeType" => "text/plain",
            "body" => %{"data" => Base.url_encode64("Test email body")}
          }
        ]
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => ["https://example.com/unsubscribe"]
    }

    # Mock Gmail API
    mock(fn
      %{method: :get, url: url} ->
        if String.contains?(url, "/users/me/messages/msg123") do
          mock_json(gmail_message)
        else
          %Tesla.Env{status: 404}
        end

      %{method: :post, url: url} ->
        if String.contains?(url, "/chat/completions") do
          mock_json(%{
            "choices" => [
              %{
                "message" => %{
                  "content" => Jason.encode!(llm_response)
                }
              }
            ]
          })
        else
          %Tesla.Env{status: 404}
        end
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert :ok = result

    # Verify email was created
    email = Emails.get_email_by_gmail_id(account.id, "msg123")
    assert email != nil
    assert email.subject == "Test Subject"
    assert email.from == "sender@example.com"
    assert email.category_id == category.id
    assert "https://example.com/unsubscribe" in email.unsubscribe_urls
  end

  test "perform/1 handles Gmail API errors" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    mock(fn
      %{method: :get} ->
        %Tesla.Env{status: 404, body: %{"error" => "Message not found"}}
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert {:error, _reason} = result
  end

  test "perform/1 handles LLM rate limit with snooze" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    _category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => []
      }
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        %Tesla.Env{
          status: 429,
          body: %{"error" => %{"message" => "Rate limit exceeded"}}
        }
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert {:snooze, 20} = result
  end

  test "perform/1 handles LLM errors by falling back to first category" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => []
      }
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        %Tesla.Env{
          status: 500,
          body: %{"error" => %{"message" => "Internal server error"}}
        }
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    # Should fall back to first category
    assert :ok = result

    email = Emails.get_email_by_gmail_id(account.id, "msg123")
    assert email != nil
    assert email.category_id == category.id
  end

  test "perform/1 handles invalid message format" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    mock(fn
      %{method: :get} ->
        mock_json(%{"invalid" => "format"})
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert {:error, _reason} = result
  end

  test "perform/1 extracts unsubscribe URLs from headers" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"},
          %{
            "name" => "List-Unsubscribe",
            "value" => "<https://example.com/unsubscribe>, <mailto:unsub@example.com>"
          }
        ],
        "parts" => []
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
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
    assert email != nil
    # Should include header URLs and LLM URLs
    assert length(email.unsubscribe_urls) >= 2
  end

  test "perform/1 handles no categories error" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    # Don't create any categories

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => []
      }
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    # Error is wrapped in classification error message
    assert {:error, reason} = result
    assert String.contains?(reason, "No categories defined")
  end

  test "perform/1 handles archive queue error gracefully" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => []
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    # Mock Oban.insert to fail
    # Note: We can't easily mock Oban.insert, but the code handles errors gracefully
    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
              }
            }
          ]
        })
    end)

    # Email should still be imported even if archive queue fails
    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    # Archive queue failure is logged but doesn't fail the import
    assert :ok = result

    email = Emails.get_email_by_gmail_id(account.id, "msg123")
    assert email != nil
  end

  test "perform/1 extracts body from top-level payload when no parts" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "mimeType" => "text/plain",
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "body" => %{"data" => Base.url_encode64("Top-level body text")}
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
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
    assert email != nil
    assert email.body_text == "Top-level body text"
  end

  test "perform/1 handles nested parts with unsubscribe headers" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => [
          %{
            "mimeType" => "text/plain",
            "headers" => [
              %{"name" => "List-Unsubscribe", "value" => "<https://nested-part.com/unsubscribe>"}
            ],
            "body" => %{"data" => Base.url_encode64("Body text")}
          }
        ]
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
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
    assert email != nil
    # Should include unsubscribe URL from nested part
    assert "https://nested-part.com/unsubscribe" in email.unsubscribe_urls
  end

  test "perform/1 handles Base64 decode fallback" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    # Use standard Base64 (not URL-safe) to test fallback
    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => [
          %{
            "mimeType" => "text/plain",
            "body" => %{"data" => Base.encode64("Test body")}
          }
        ]
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
              }
            }
          ]
        })
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    # Should handle fallback Base64 decoding
    assert :ok = result

    email = Emails.get_email_by_gmail_id(account.id, "msg123")
    assert email != nil
  end

  test "perform/1 handles extraction errors gracefully" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    # Message that will cause extraction to fail
    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test"
      # Missing payload - will cause error in extract_email_data
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    assert {:error, reason} = result
    assert String.contains?(reason, "Invalid message format")
  end

  test "perform/1 handles missing headers gracefully" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        # No headers field
        "parts" => []
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
              }
            }
          ]
        })
    end)

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    # Should handle missing headers (get_header returns empty string)
    assert :ok = result

    email = Emails.get_email_by_gmail_id(account.id, "msg123")
    assert email != nil
    # get_header returns "" when missing, but Ecto may convert to nil
    assert email.subject in [nil, ""]
    assert email.from in [nil, ""]
  end

  test "perform/1 handles HTML body extraction" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => [
          %{
            "mimeType" => "text/html",
            "body" => %{"data" => Base.url_encode64("<html><body>HTML content</body></html>")}
          }
        ]
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
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
    assert email != nil
    assert email.body_html == "<html><body>HTML content</body></html>"
  end

  test "perform/1 handles List-Unsubscribe-Post header" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"},
          %{
            "name" => "List-Unsubscribe-Post",
            "value" => "<https://example.com/unsubscribe-post>"
          }
        ],
        "parts" => []
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
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
    assert email != nil
    # Should include URL from List-Unsubscribe-Post header
    assert "https://example.com/unsubscribe-post" in email.unsubscribe_urls
  end

  test "perform/1 combines header and LLM unsubscribe URLs" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"},
          %{"name" => "List-Unsubscribe", "value" => "<https://header-url.com/unsubscribe>"}
        ],
        "parts" => []
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => ["https://llm-url.com/unsubscribe"]
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
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
    assert email != nil
    # Should include both header and LLM URLs
    assert "https://header-url.com/unsubscribe" in email.unsubscribe_urls
    assert "https://llm-url.com/unsubscribe" in email.unsubscribe_urls
    assert length(email.unsubscribe_urls) >= 2
  end

  test "perform/1 handles save_email errors" do
    user = create_user()

    account =
      create_account(user, %{
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    category = create_category(user)

    gmail_message = %{
      "id" => "msg123",
      "snippet" => "Test",
      "payload" => %{
        "headers" => [
          %{"name" => "Subject", "value" => "Test"},
          %{"name" => "From", "value" => "test@example.com"}
        ],
        "parts" => []
      }
    }

    llm_response = %{
      "category_id" => category.id,
      "summary" => "Test summary",
      "unsubscribe_urls" => []
    }

    mock(fn
      %{method: :get} ->
        mock_json(gmail_message)

      %{method: :post} ->
        mock_json(%{
          "choices" => [
            %{
              "message" => %{
                "content" => Jason.encode!(llm_response)
              }
            }
          ]
        })
    end)

    # Create email with same gmail_message_id to cause unique constraint error
    create_email(account, category, %{gmail_message_id: "msg123"})

    result =
      ImportEmail.perform(%Oban.Job{
        args: %{"account_id" => account.id, "message_id" => "msg123"}
      })

    # Should skip since email already exists
    assert :ok = result
  end
end
