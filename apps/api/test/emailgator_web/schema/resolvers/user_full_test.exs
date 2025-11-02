defmodule EmailgatorWeb.Schema.Resolvers.UserFullTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.User

  describe "me/3" do
    test "returns user when authenticated" do
      user = create_user()
      context = build_context(user)

      assert {:ok, returned_user} = User.me(nil, %{}, context)
      assert returned_user.id == user.id
      assert returned_user.email == user.email
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = User.me(nil, %{}, %{})
    end

    test "returns error when context has nil current_user" do
      context = %{context: %{current_user: nil}}
      assert {:error, "Not authenticated"} = User.me(nil, %{}, context)
    end
  end
end
