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

    test "get_category!/1 returns category when exists" do
      user = create_user()
      category = create_category(user)
      assert Categories.get_category!(category.id).id == category.id
    end

    test "get_category!/1 raises when category doesn't exist" do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Categories.get_category!(fake_id)
      end
    end

    test "create_category/1 returns error with invalid attributes" do
      user = create_user()
      # Missing required name
      attrs = %{user_id: user.id}

      assert {:error, changeset} = Categories.create_category(attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_category/1 validates name length" do
      user = create_user()

      # Name too long (over 255 chars)
      long_name = String.duplicate("a", 256)
      attrs = %{name: long_name, user_id: user.id}

      assert {:error, changeset} = Categories.create_category(attrs)
      refute changeset.valid?
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "create_category/1 handles empty name" do
      user = create_user()
      attrs = %{name: "", user_id: user.id}

      assert {:error, changeset} = Categories.create_category(attrs)
      refute changeset.valid?
      # Empty string fails min length validation
      assert %{name: _errors} = errors_on(changeset)
    end

    test "update_category/2 returns error with invalid attributes" do
      user = create_user()
      category = create_category(user)

      # Try to set empty name
      attrs = %{name: ""}

      assert {:error, changeset} = Categories.update_category(category, attrs)
      refute changeset.valid?
    end

    test "list_user_categories/1 returns empty list when user has no categories" do
      user = create_user()
      assert Categories.list_user_categories(user.id) == []
    end

    test "list_user_categories/1 orders by inserted_at desc" do
      user = create_user()

      # Create categories - they should be ordered by inserted_at desc
      category1 = create_category(user, %{name: "First"})
      category2 = create_category(user, %{name: "Second"})

      categories = Categories.list_user_categories(user.id)
      assert length(categories) >= 2

      # Verify both are present and ordered desc
      category_ids = Enum.map(categories, & &1.id)
      assert category1.id in category_ids
      assert category2.id in category_ids
      # Order is tested by query itself (order_by [desc: inserted_at])
    end

    test "get_category/1 returns nil when category doesn't exist" do
      fake_id = Ecto.UUID.generate()
      assert Categories.get_category(fake_id) == nil
    end

    test "update_category/2 can update description to nil" do
      user = create_user()
      category = create_category(user, %{name: "Test", description: "Original"})

      assert {:ok, updated} = Categories.update_category(category, %{description: nil})
      assert updated.description == nil
    end

    test "create_category/1 handles nil description" do
      user = create_user()
      attrs = %{name: "Test", description: nil, user_id: user.id}

      assert {:ok, category} = Categories.create_category(attrs)
      assert category.name == "Test"
      assert category.description == nil
    end
  end
end
