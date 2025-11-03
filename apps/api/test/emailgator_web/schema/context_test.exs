defmodule EmailgatorWeb.Schema.ContextTest do
  use EmailgatorWeb.ConnCase
  use ExUnit.Case

  alias EmailgatorWeb.Schema.Context
  alias Emailgator.Accounts

  setup do
    # Ensure we're using the test repo
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Emailgator.Repo)
    :ok
  end

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [test: true]
      assert Context.init(opts) == opts
    end
  end

  describe "call/2" do
    test "sets current_user in context when user_id in session" do
      user = create_user(%{email: "test@example.com", name: "Test User"})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Context.call([])

      context = conn.private[:absinthe][:context]
      assert context[:current_user].id == user.id
      assert context[:current_user].email == user.email
    end

    test "sets current_user to nil when no user_id in session" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Context.call([])

      context = conn.private[:absinthe][:context]
      assert context[:current_user] == nil
    end

    test "sets current_user to nil when user_id doesn't exist in database" do
      # Use a valid UUID format that doesn't exist in the database
      fake_user_id = Ecto.UUID.generate()

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, fake_user_id)
        |> Context.call([])

      context = conn.private[:absinthe][:context]
      assert context[:current_user] == nil
    end

    test "handles session without user_id key" do
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{other_key: "value"})
        |> Context.call([])

      context = conn.private[:absinthe][:context]
      assert context[:current_user] == nil
    end

    test "retrieves user from Accounts.get_user" do
      user = create_user(%{email: "test@example.com", name: "Test User"})

      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Context.call([])

      context = conn.private[:absinthe][:context]
      retrieved_user = context[:current_user]
      assert retrieved_user != nil
      assert retrieved_user.id == user.id
      assert retrieved_user.email == user.email
      assert retrieved_user.name == user.name
    end
  end
end
