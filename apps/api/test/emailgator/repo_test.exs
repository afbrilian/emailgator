defmodule Emailgator.RepoTest do
  use Emailgator.DataCase
  alias Emailgator.Repo

  test "repo can execute queries" do
    # Test that the repo is properly configured and can execute queries
    result = Repo.query("SELECT 1 as test")
    assert {:ok, _} = result
  end

  test "repo returns query results" do
    {:ok, result} = Repo.query("SELECT 42 as answer")
    assert result.num_rows == 1
    assert List.first(result.rows) == [42]
  end

  test "repo handles invalid queries gracefully" do
    result = Repo.query("SELECT * FROM nonexistent_table")
    assert match?({:error, _}, result)
  end

  test "repo module exists" do
    assert Code.ensure_loaded?(Repo)
    assert function_exported?(Repo, :query, 1)
    assert function_exported?(Repo, :all, 1)
    assert function_exported?(Repo, :get, 2)
  end
end
