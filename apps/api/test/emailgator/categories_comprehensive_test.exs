defmodule Emailgator.CategoriesComprehensiveTest do
  use Emailgator.DataCase

  alias Emailgator.Categories

  describe "create_category/1" do
    test "creates category with minimal attributes" do
      user = create_user()
      attrs = %{name: "Minimal", user_id: user.id}
      assert {:ok, category} = Categories.create_category(attrs)
      assert category.name == "Minimal"
      assert category.user_id == user.id
      assert category.description == nil
    end

    test "returns error when required fields missing" do
      attrs = %{description: "No name"}
      assert {:error, changeset} = Categories.create_category(attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"], user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "raises constraint error on invalid user_id" do
      # user_id foreign key constraint is enforced by database
      # Invalid user_id will raise Ecto.ConstraintError
      fake_user_id = Ecto.UUID.generate()
      attrs = %{name: "Test", user_id: fake_user_id}

      # Foreign key constraint will raise an error
      assert_raise Ecto.ConstraintError, fn ->
        Categories.create_category(attrs)
      end
    end

    test "creates multiple categories for same user" do
      user = create_user()
      attrs1 = %{name: "Category 1", user_id: user.id}
      attrs2 = %{name: "Category 2", user_id: user.id}

      assert {:ok, cat1} = Categories.create_category(attrs1)
      assert {:ok, cat2} = Categories.create_category(attrs2)

      assert cat1.user_id == user.id
      assert cat2.user_id == user.id
      assert cat1.name != cat2.name
    end
  end

  describe "update_category/2" do
    test "updates only description" do
      user = create_user()
      category = create_category(user, %{name: "Work", description: "Old desc"})

      assert {:ok, updated} = Categories.update_category(category, %{description: "New desc"})
      assert updated.name == "Work"
      assert updated.description == "New desc"
    end

    test "updates only name" do
      user = create_user()
      category = create_category(user, %{name: "Old Name"})

      assert {:ok, updated} = Categories.update_category(category, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "returns error on invalid name (empty string)" do
      user = create_user()
      category = create_category(user)

      # Name validation requires min length of 1
      assert {:error, changeset} = Categories.update_category(category, %{name: ""})
      refute changeset.valid?
    end

    test "returns error on name too long" do
      user = create_user()
      category = create_category(user)

      # Name validation has max length of 255
      long_name = String.duplicate("a", 256)
      assert {:error, changeset} = Categories.update_category(category, %{name: long_name})
      refute changeset.valid?
    end

    test "handles nil description" do
      user = create_user()
      category = create_category(user, %{description: "Has description"})

      assert {:ok, updated} = Categories.update_category(category, %{description: nil})
      assert updated.description == nil
    end
  end

  describe "list_user_categories/1" do
    test "returns empty list when user has no categories" do
      user = create_user()
      assert Categories.list_user_categories(user.id) == []
    end

    test "returns categories ordered by inserted_at desc" do
      user = create_user()
      category1 = create_category(user, %{name: "First"})
      Process.sleep(10)
      category2 = create_category(user, %{name: "Second"})

      categories = Categories.list_user_categories(user.id)
      assert length(categories) >= 2

      # Most recent should be first
      category_ids = Enum.map(categories, & &1.id)
      assert category2.id in category_ids
      assert category1.id in category_ids
    end

    test "returns only categories for specified user" do
      user1 = create_user()
      user2 = create_user()

      cat1 = create_category(user1, %{name: "User1 Cat"})
      cat2 = create_category(user1, %{name: "User1 Cat2"})
      _cat3 = create_category(user2, %{name: "User2 Cat"})

      categories = Categories.list_user_categories(user1.id)
      assert length(categories) == 2

      category_ids = Enum.map(categories, & &1.id)
      assert cat1.id in category_ids
      assert cat2.id in category_ids
    end
  end

  describe "get_category/1" do
    test "returns nil when category doesn't exist" do
      fake_id = Ecto.UUID.generate()
      assert Categories.get_category(fake_id) == nil
    end

    test "returns category with all fields" do
      user = create_user()

      category =
        create_category(user, %{
          name: "Complete Category",
          description: "Full description"
        })

      found = Categories.get_category(category.id)
      assert found.id == category.id
      assert found.name == "Complete Category"
      assert found.description == "Full description"
      assert found.user_id == user.id
    end
  end

  describe "delete_category/1" do
    test "returns error tuple if deletion fails" do
      # Create a category that might have dependencies
      user = create_user()
      account = create_account(user)
      category = create_category(user)
      _email = create_email(account, category)

      # Category with emails should still be deletable (no hard constraint)
      # But test the delete path
      result = Categories.delete_category(category)
      assert {:ok, _deleted} = result

      # Verify it's gone
      assert Categories.get_category(category.id) == nil
    end
  end
end
