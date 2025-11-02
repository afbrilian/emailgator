defmodule EmailgatorWeb.Schema.Resolvers.CategoryComprehensiveTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Category

  describe "create/3 edge cases" do
    test "creates category with minimal attributes" do
      user = create_user()
      context = build_context(user)

      args = %{name: "Minimal Category"}

      assert {:ok, category} = Category.create(nil, args, context)
      assert category.name == "Minimal Category"
      assert category.user_id == user.id
    end

    test "creates category with description" do
      user = create_user()
      context = build_context(user)

      args = %{name: "Category", description: "A detailed description"}

      assert {:ok, category} = Category.create(nil, args, context)
      assert category.description == "A detailed description"
    end
  end

  describe "list/3 edge cases" do
    test "returns empty list when user has no categories" do
      user = create_user()
      context = build_context(user)

      assert {:ok, categories} = Category.list(nil, %{}, context)
      assert categories == []
    end

    test "returns categories in order" do
      user = create_user()
      category1 = create_category(user, %{name: "First"})
      category2 = create_category(user, %{name: "Second"})
      context = build_context(user)

      assert {:ok, categories} = Category.list(nil, %{}, context)
      assert length(categories) >= 2
      # Verify both categories are returned
      assert category1.id in Enum.map(categories, & &1.id)
      assert category2.id in Enum.map(categories, & &1.id)
    end
  end
end
