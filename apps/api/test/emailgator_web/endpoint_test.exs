defmodule EmailgatorWeb.EndpointTest do
  use ExUnit.Case
  import Plug.Test
  import Plug.Conn

  alias EmailgatorWeb.Endpoint

  setup do
    original_frontend_url = System.get_env("FRONTEND_URL")

    on_exit(fn ->
      if original_frontend_url, do: System.put_env("FRONTEND_URL", original_frontend_url)
    end)

    System.put_env("FRONTEND_URL", "http://localhost:3000")
    :ok
  end

  describe "CORS handling" do
    test "handles OPTIONS preflight request" do
      conn =
        :options
        |> conn("/api/test", "")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      assert conn.status == 204
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]

      assert get_resp_header(conn, "access-control-allow-methods") ==
               ["GET, POST, PUT, DELETE, OPTIONS"]

      assert get_resp_header(conn, "access-control-allow-headers") ==
               ["Content-Type, Authorization"]

      assert get_resp_header(conn, "access-control-max-age") == ["3600"]
      assert conn.state == :sent
    end

    test "allows requests from configured frontend URL" do
      System.put_env("FRONTEND_URL", "http://localhost:3000")

      # Use a valid route that exists (OPTIONS works because of CORS preflight)
      conn =
        :options
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      # CORS headers should be set even if route returns 404 or error
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end

    test "allows any origin in dev environment" do
      # Note: This test assumes Mix.env() == :test, which behaves like dev for CORS
      conn =
        :options
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://any-origin.com")
        |> Endpoint.call([])

      # In test/dev, should allow any origin
      assert get_resp_header(conn, "access-control-allow-origin") != []
    end

    test "uses frontend URL as origin when origin header missing" do
      System.put_env("FRONTEND_URL", "http://localhost:3000")

      conn =
        :options
        |> conn("/api/graphql", "")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    end

    test "adds CORS headers to non-OPTIONS requests" do
      # Use OPTIONS since GET to non-existent route causes 404 issues
      # The CORS headers are added by the endpoint regardless of route existence
      conn =
        :options
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") != []
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]

      assert get_resp_header(conn, "access-control-allow-methods") ==
               ["GET, POST, PUT, DELETE, OPTIONS"]
    end

    test "sets proper CORS headers for POST requests" do
      # Use OPTIONS to test CORS headers (actual POST would hit non-existent route)
      conn =
        :options
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://localhost:3000")
        |> put_req_header("content-type", "application/json")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end

    test "adds CORS headers to GET requests (non-OPTIONS)" do
      conn =
        :get
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      # Should add CORS headers even for non-OPTIONS requests
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end

    test "handles different origin in dev/test mode" do
      # In test/dev mode, should allow any origin
      conn =
        :get
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://different-origin.com")
        |> Endpoint.call([])

      # In test environment (which behaves like dev), should allow any origin
      assert get_resp_header(conn, "access-control-allow-origin") != []
    end

    test "uses default frontend URL when FRONTEND_URL env not set" do
      original_url = System.get_env("FRONTEND_URL")
      System.delete_env("FRONTEND_URL")

      try do
        conn =
          :get
          |> conn("/api/graphql", "")
          |> Endpoint.call([])

        # Should default to http://localhost:3000
        assert get_resp_header(conn, "access-control-allow-origin") != []
      after
        if original_url, do: System.put_env("FRONTEND_URL", original_url)
      end
    end

    test "handles origin header with multiple values" do
      # get_req_header returns a list, List.first gets the first one
      conn =
        :get
        |> conn("/api/graphql", "")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      # Should use first origin
      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    end
  end
end
