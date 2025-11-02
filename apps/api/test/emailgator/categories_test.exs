defmodule Emailgator.CategoriesTest do
  use Emailgator.DataCase

  alias Emailgator.Categories

  describe "categories" do
    test "create_category/1 creates category with valid attributes" do
      user = create_user()
      attrs = %{name: "Work", description: "Work emails", user_id: user.id}
      assert {:ok, category} = Categories.create_category(attrs)
      assert category.name == "Work"
      assert category.description == "Work emails"
      assert category.user_id == user.id
    end

    test "list_user_categories/1 returns categories for user" do
      user1 = create_user(%{email: "user1@example.com"})
      user2 = create_user(%{email: "user2@example.com"})

      category1 = create_category(user1, %{name: "Category 1"})
      category2 = create_category(user1, %{name: "Category 2"})
      _category3 = create_category(user2, %{name: "Category 3"})

      categories = Categories.list_user_categories(user1.id)
      assert length(categories) == 2
      assert category1.id in Enum.map(categories, & &1.id)
      assert category2.id in Enum.map(categories, & &1.id)
    end

    test "get_category/1 returns category when exists" do
      user = create_user()
      category = create_category(user)
      assert Categories.get_category(category.id).id == category.id
    end

    test "update_category/2 updates category" do
      user = create_user()
      category = create_category(user, %{name: "Old Name"})
      attrs = %{name: "New Name"}
      assert {:ok, updated} = Categories.update_category(category, attrs)
      assert updated.name == "New Name"
    end

    test "delete_category/1 deletes category" do
      user = create_user()
      category = create_category(user)
      assert {:ok, _} = Categories.delete_category(category)
      assert Categories.get_category(category.id) == nil
    end
  end
end
