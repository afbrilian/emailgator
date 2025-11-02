defmodule EmailgatorWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  GraphQL tests that require a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import EmailgatorWeb.ConnCase
      import Emailgator.DataCase
      import Plug.Test
    end
  end

  @doc """
  Creates a context with a current_user for GraphQL tests.
  """
  def build_context(user) do
    %{context: %{current_user: user}}
  end

  @doc """
  Helper to build a GraphQL query/mutation string.
  """
  def query(query_string, variables \\ %{}) do
    %{
      query: query_string,
      variables: variables
    }
  end
end
