defmodule EmailgatorWeb.Schema.Resolvers.UserTest do
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.User

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Emailgator.Repo)
    :ok
  end

  describe "me/3" do
    test "returns current user when authenticated" do
      user = create_user(%{email: "test@example.com", name: "Test User"})
      context = %{context: %{current_user: user}}

      assert {:ok, found_user} = User.me(nil, %{}, context)
      assert found_user.id == user.id
      assert found_user.email == user.email
      assert found_user.name == user.name
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = User.me(nil, %{}, context)
    end

    test "returns error when current_user is nil" do
      context = %{context: %{current_user: nil}}
      assert {:error, "Not authenticated"} = User.me(nil, %{}, context)
    end
  end
end
