defmodule EmailgatorWeb.EndpointTest do
  use ExUnit.Case
  use Plug.Test

  alias EmailgatorWeb.Endpoint
  import Plug.Test

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

      conn =
        :get
        |> conn("/api/test")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end

    test "allows any origin in dev environment" do
      # Note: This test assumes Mix.env() == :test, which behaves like dev for CORS
      conn =
        :get
        |> conn("/api/test")
        |> put_req_header("origin", "http://any-origin.com")
        |> Endpoint.call([])

      # In test/dev, should allow any origin
      assert get_resp_header(conn, "access-control-allow-origin") != []
    end

    test "uses frontend URL as origin when origin header missing" do
      System.put_env("FRONTEND_URL", "http://localhost:3000")

      conn =
        :get
        |> conn("/api/test")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    end

    test "adds CORS headers to non-OPTIONS requests" do
      conn =
        :get
        |> conn("/api/test")
        |> put_req_header("origin", "http://localhost:3000")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") != []
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
      assert get_resp_header(conn, "access-control-allow-methods") ==
               ["GET, POST, PUT, DELETE, OPTIONS"]
    end

    test "sets proper CORS headers for POST requests" do
      conn =
        :post
        |> conn("/api/test", "{}")
        |> put_req_header("origin", "http://localhost:3000")
        |> put_req_header("content-type", "application/json")
        |> Endpoint.call([])

      assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
      assert get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end
  end
end
