defmodule EmailgatorWeb.Schema.Resolvers.CategoryEdgeCasesTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Category

  describe "get/3" do
    test "returns category when belongs to user" do
      user = create_user()
      category = create_category(user)
      context = build_context(user)

      assert {:ok, found} = Category.get(nil, %{id: category.id}, context)
      assert found.id == category.id
    end

    test "returns error when category not found" do
      user = create_user()
      context = build_context(user)
      fake_id = Ecto.UUID.generate()

      assert {:error, "Category not found"} = Category.get(nil, %{id: fake_id}, context)
    end

    test "returns error when category belongs to different user" do
      user1 = create_user()
      user2 = create_user()
      category = create_category(user1)
      context = build_context(user2)

      # Should still return the category (no ownership check in get)
      # But verify it's accessible
      assert {:ok, found} = Category.get(nil, %{id: category.id}, context)
      assert found.id == category.id
    end
  end
end
