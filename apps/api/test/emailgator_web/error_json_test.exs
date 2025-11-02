defmodule EmailgatorWeb.ErrorJSONTest do
  use ExUnit.Case

  alias EmailgatorWeb.ErrorJSON

  describe "error/1" do
    test "formats changeset errors" do
      changeset = %Ecto.Changeset{
        errors: [email: {"can't be blank", []}],
        data: %Emailgator.Accounts.User{},
        valid?: false
      }

      result = ErrorJSON.error(%{changeset: changeset})
      assert Map.has_key?(result, :errors)
    end

    test "formats message errors" do
      result = ErrorJSON.error(%{message: "Something went wrong"})
      assert result == %{error: "Something went wrong"}
    end

    test "formats error field" do
      result = ErrorJSON.error(%{error: "Custom error"})
      assert result == %{error: "Custom error"}
    end
  end

  describe "render/2" do
    test "renders 404" do
      result = ErrorJSON.render(:"404", %{})
      assert result == %{error: "Not found"}
    end

    test "renders 401" do
      result = ErrorJSON.render(:"401", %{})
      assert result == %{error: "Unauthorized"}
    end
  end
end
