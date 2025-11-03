defmodule Emailgator.CategoriesEdgeCasesTest do
  use Emailgator.DataCase

  alias Emailgator.Categories

  describe "edge cases" do
    test "create_category with empty description" do
      user = create_user()
      attrs = %{name: "Work", description: "", user_id: user.id}

      assert {:ok, category} = Categories.create_category(attrs)
      assert category.name == "Work"
      # Empty string may be stored as nil in database
      assert category.description in [nil, ""]
    end

    test "create_category with nil description" do
      user = create_user()
      attrs = %{name: "Personal", description: nil, user_id: user.id}

      assert {:ok, category} = Categories.create_category(attrs)
      assert category.name == "Personal"
      assert category.description == nil
    end

    test "update_category with empty string" do
      user = create_user()
      category = create_category(user, %{name: "Old", description: "Old desc"})

      attrs = %{name: "New", description: ""}
      assert {:ok, updated} = Categories.update_category(category, attrs)
      assert updated.name == "New"
      # Empty string may be stored as nil in database
      assert updated.description in [nil, ""]
    end

    test "list_user_categories returns empty list for new user" do
      user = create_user()

      assert Categories.list_user_categories(user.id) == []
    end

    test "get_category returns nil for non-existent category" do
      fake_id = Ecto.UUID.generate()
      assert Categories.get_category(fake_id) == nil
    end

    test "get_category! raises for non-existent category" do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Categories.get_category!(fake_id)
      end
    end

    test "delete_category removes category successfully" do
      user = create_user()
      category = create_category(user)

      assert {:ok, _deleted} = Categories.delete_category(category)
      assert Categories.get_category(category.id) == nil
    end

    test "update_category with only name" do
      user = create_user()
      category = create_category(user, %{name: "Original", description: "Original desc"})

      attrs = %{name: "Updated"}
      assert {:ok, updated} = Categories.update_category(category, attrs)
      assert updated.name == "Updated"
      assert updated.description == "Original desc"
    end

    test "update_category with only description" do
      user = create_user()
      category = create_category(user, %{name: "Original", description: "Original desc"})

      attrs = %{description: "New description"}
      assert {:ok, updated} = Categories.update_category(category, attrs)
      assert updated.name == "Original"
      assert updated.description == "New description"
    end

    test "create_category preserves user_id when provided" do
      user1 = create_user()
      user2 = create_user()

      category = create_category(user1)
      assert category.user_id == user1.id
      assert category.user_id != user2.id
    end

    test "list_user_categories respects user boundaries" do
      user1 = create_user()
      user2 = create_user()

      cat1 = create_category(user1, %{name: "User1 Category"})
      cat2 = create_category(user1, %{name: "User1 Category 2"})
      _cat3 = create_category(user2, %{name: "User2 Category"})

      categories = Categories.list_user_categories(user1.id)
      category_ids = Enum.map(categories, & &1.id)

      assert cat1.id in category_ids
      assert cat2.id in category_ids
      assert length(categories) == 2
    end
  end
end
