defmodule EmailgatorWeb.FallbackControllerTest do
  use EmailgatorWeb.ConnCase
  use ExUnit.Case

  alias EmailgatorWeb.FallbackController
  alias EmailgatorWeb.ErrorJSON

  describe "call/2 with changeset error" do
    test "returns 422 with changeset errors" do
      changeset =
        %Emailgator.Accounts.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "can't be blank")

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_private(:phoenix_format, "json")
        |> Map.put(:params, %{})
        |> FallbackController.call({:error, changeset})

      assert conn.status == 422
      assert %{"errors" => _} = Jason.decode!(conn.resp_body)
    end

    test "formats multiple changeset errors" do
      changeset =
        %Emailgator.Accounts.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "can't be blank")
        |> Ecto.Changeset.add_error(:name, "can't be blank")

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_private(:phoenix_format, "json")
        |> Map.put(:params, %{})
        |> FallbackController.call({:error, changeset})

      assert conn.status == 422
      result = Jason.decode!(conn.resp_body)
      assert Map.has_key?(result, "errors")
    end
  end

  describe "call/2 with not_found error" do
    test "returns 404 error" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_private(:phoenix_format, "json")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Map.put(:params, %{})
        |> FallbackController.call({:error, :not_found})

      assert conn.status == 404
      result = Jason.decode!(conn.resp_body)
      assert Map.has_key?(result, "message") or Map.has_key?(result, "error")
    end
  end

  describe "call/2 with unauthorized error" do
    test "returns 401 error" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_private(:phoenix_format, "json")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Map.put(:params, %{})
        |> FallbackController.call({:error, :unauthorized})

      assert conn.status == 401
      result = Jason.decode!(conn.resp_body)
      assert Map.has_key?(result, "message") or Map.has_key?(result, "error")
    end
  end
end
