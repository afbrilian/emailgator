defmodule Emailgator.CategoriesFullTest do
  use Emailgator.DataCase

  alias Emailgator.Categories

  describe "get_category!/1" do
    test "returns category when found" do
      user = create_user()
      category = create_category(user)

      found = Categories.get_category!(category.id)
      assert found.id == category.id
    end

    test "raises when not found" do
      fake_id = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Categories.get_category!(fake_id)
      end
    end
  end
end
