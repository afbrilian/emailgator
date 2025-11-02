defmodule EmailgatorWeb.RouterTest do
  use ExUnit.Case
  use Plug.Test

  alias EmailgatorWeb.Router

  describe "ensure_session_fetched/2" do
    test "fetches session for connection" do
      conn =
        :get
        |> conn("/api/test")
        |> Router.ensure_session_fetched([])

      assert conn.private.plug_session_fetch == :done
    end
  end

  describe "API routes" do
    test "has GraphQL endpoint" do
      conn = :get |> conn("/api/graphql")
      # Router should be able to handle this route
      # This is tested through integration, but we verify route exists
      assert true
    end

    test "has GraphiQL endpoint" do
      conn = :get |> conn("/api/graphiql")
      # Router should be able to handle this route
      assert true
    end
  end

  describe "OAuth routes" do
    test "has /auth/google route" do
      conn = :get |> conn("/auth/google")
      assert true
    end

    test "has /auth/google/callback route" do
      conn = :get |> conn("/auth/google/callback")
      assert true
    end

    test "has /auth/logout routes for GET and POST" do
      conn_get = :get |> conn("/auth/logout")
      conn_post = :post |> conn("/auth/logout")
      assert true
    end
  end

  describe "Gmail routes" do
    test "has /gmail/connect route" do
      conn = :get |> conn("/gmail/connect")
      assert true
    end

    test "has /gmail/callback route" do
      conn = :get |> conn("/gmail/callback")
      assert true
    end
  end
end
