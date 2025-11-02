defmodule EmailgatorWeb.Schema.Resolvers.UserTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.User

  describe "me/3" do
    test "returns user when authenticated" do
      user = create_user()
      context = build_context(user)

      assert {:ok, returned_user} = User.me(nil, %{}, context)
      assert returned_user.id == user.id
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = User.me(nil, %{}, %{})
    end
  end
end
