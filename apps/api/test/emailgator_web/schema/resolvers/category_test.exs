defmodule EmailgatorWeb.Schema.Resolvers.CategoryTest do
  use Emailgator.DataCase
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Category

  describe "list/3" do
    test "returns categories for authenticated user" do
      user = create_user()
      category1 = create_category(user, %{name: "Category 1"})
      category2 = create_category(user, %{name: "Category 2"})
      context = build_context(user)

      assert {:ok, categories} = Category.list(nil, %{}, context)
      assert length(categories) == 2
      assert category1.id in Enum.map(categories, & &1.id)
      assert category2.id in Enum.map(categories, & &1.id)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Category.list(nil, %{}, %{})
    end
  end

  describe "create/3" do
    test "creates category for authenticated user" do
      user = create_user()
      context = build_context(user)

      args = %{name: "New Category", description: "A new category"}

      assert {:ok, category} = Category.create(nil, args, context)
      assert category.name == "New Category"
      assert category.user_id == user.id
    end

    test "returns error when not authenticated" do
      args = %{name: "New Category"}
      assert {:error, "Not authenticated"} = Category.create(nil, args, %{})
    end
  end

  describe "update/3" do
    test "updates category for authenticated user" do
      user = create_user()
      category = create_category(user, %{name: "Old Name"})
      context = build_context(user)

      args = %{id: category.id, name: "New Name"}

      assert {:ok, updated} = Category.update(nil, args, context)
      assert updated.name == "New Name"
    end

    test "returns error when category not found" do
      user = create_user()
      context = build_context(user)
      args = %{id: Ecto.UUID.generate(), name: "New Name"}

      assert {:error, "Category not found"} = Category.update(nil, args, context)
    end

    test "returns error when not authenticated" do
      assert {:error, "Not authenticated"} = Category.update(nil, %{}, %{})
    end
  end

  describe "delete/3" do
    test "deletes category for authenticated user" do
      user = create_user()
      category = create_category(user)
      context = build_context(user)

      assert {:ok, _} = Category.delete(nil, %{id: category.id}, context)
      assert Emailgator.Categories.get_category(category.id) == nil
    end

    test "returns error when category not found" do
      user = create_user()
      context = build_context(user)
      args = %{id: Ecto.UUID.generate()}

      assert {:error, "Category not found"} = Category.delete(nil, args, context)
    end
  end
end
