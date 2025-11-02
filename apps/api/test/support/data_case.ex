defmodule Emailgator.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  database access.

  You may define functions here to be used as helpers in
  your tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Emailgator.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Emailgator.DataCase
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Emailgator.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Emailgator.Repo, {:shared, self()})
    end

    :ok
  end

  @doc """
  Helper function to create a user for testing.
  """
  def create_user(attrs \\ %{}) do
    # Generate unique email to avoid unique constraint violations
    email = attrs[:email] || "test_#{System.unique_integer([:positive])}@example.com"

    defaults = %{
      email: email,
      name: "Test User"
    }

    attrs = Map.merge(defaults, attrs)
    {:ok, user} = Emailgator.Accounts.create_user(attrs)
    user
  end

  @doc """
  Helper function to create an account for testing.
  """
  def create_account(user, attrs \\ %{}) do
    # Generate unique email to avoid unique constraint violations (user_id, email)
    email = attrs[:email] || "gmail_#{System.unique_integer([:positive])}@example.com"

    defaults = %{
      email: email,
      refresh_token: attrs[:refresh_token] || "refresh_token_123",
      access_token: attrs[:access_token] || "access_token_123",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      user_id: user.id
    }

    attrs = Map.merge(defaults, attrs)
    {:ok, account} = Emailgator.Accounts.create_account(attrs)
    account
  end

  @doc """
  Helper function to create a category for testing.
  """
  def create_category(user, attrs \\ %{}) do
    defaults = %{
      name: "Test Category",
      description: "A test category",
      user_id: user.id
    }

    attrs = Map.merge(defaults, attrs)
    {:ok, category} = Emailgator.Categories.create_category(attrs)
    category
  end

  @doc """
  Helper function to create an email for testing.
  """
  def create_email(account, category, attrs \\ %{}) do
    # Generate unique gmail_message_id to avoid unique constraint violations
    gmail_id = attrs[:gmail_message_id] || "gmail_#{System.unique_integer([:positive])}"

    defaults = %{
      subject: "Test Email",
      from: "sender@example.com",
      snippet: "Test snippet",
      summary: "Test summary",
      body_text: "Test body text",
      body_html: "<p>Test body HTML</p>",
      gmail_message_id: gmail_id,
      account_id: account.id,
      category_id: category.id
    }

    attrs = Map.merge(defaults, attrs)
    {:ok, email} = Emailgator.Emails.create_email(attrs)
    email
  end
end
