defmodule EmailgatorWeb.Schema.Resolvers.CategoryTest do
  use EmailgatorWeb.ConnCase

  alias EmailgatorWeb.Schema.Resolvers.Category
  alias Emailgator.Categories

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Emailgator.Repo)
    :ok
  end

  describe "list/3" do
    test "returns user categories when authenticated" do
      user = create_user()
      category1 = create_category(user)
      category2 = create_category(user)
      _other_user = create_user()
      _other_category = create_category(_other_user)

      context = %{context: %{current_user: user}}
      assert {:ok, categories} = Category.list(nil, %{}, context)

      category_ids = Enum.map(categories, & &1.id)
      assert category1.id in category_ids
      assert category2.id in category_ids
      assert length(categories) == 2
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Category.list(nil, %{}, context)
    end
  end

  describe "get/3" do
    test "returns category when it exists" do
      user = create_user()
      category = create_category(user)
      context = %{context: %{current_user: user}}

      assert {:ok, found_category} = Category.get(nil, %{id: category.id}, context)
      assert found_category.id == category.id
    end

    test "returns error when category not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: user}}

      assert {:error, "Category not found"} = Category.get(nil, %{id: fake_id}, context)
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Category.get(nil, %{id: "test"}, context)
    end
  end

  describe "create/3" do
    test "creates category when authenticated" do
      user = create_user()
      context = %{context: %{current_user: user}}
      args = %{name: "New Category", description: "Test description"}

      assert {:ok, category} = Category.create(nil, args, context)
      assert category.name == "New Category"
      assert category.description == "Test description"
      assert category.user_id == user.id
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Category.create(nil, %{}, context)
    end
  end

  describe "update/3" do
    test "updates category when it exists" do
      user = create_user()
      category = create_category(user, %{name: "Old Name"})
      context = %{context: %{current_user: user}}
      args = %{id: category.id, name: "New Name"}

      assert {:ok, updated} = Category.update(nil, args, context)
      assert updated.name == "New Name"
    end

    test "returns error when category not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: user}}
      args = %{id: fake_id, name: "New Name"}

      assert {:error, "Category not found"} = Category.update(nil, args, context)
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Category.update(nil, %{id: "test"}, context)
    end
  end

  describe "delete/3" do
    test "deletes category when it exists" do
      user = create_user()
      category = create_category(user)
      context = %{context: %{current_user: user}}

      assert {:ok, _deleted} = Category.delete(nil, %{id: category.id}, context)
      assert Categories.get_category(category.id) == nil
    end

    test "returns error when category not found" do
      user = create_user()
      fake_id = Ecto.UUID.generate()
      context = %{context: %{current_user: user}}

      assert {:error, "Category not found"} = Category.delete(nil, %{id: fake_id}, context)
    end

    test "returns error when not authenticated" do
      context = %{context: %{}}
      assert {:error, "Not authenticated"} = Category.delete(nil, %{id: "test"}, context)
    end
  end
end
