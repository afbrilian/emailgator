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

  describe "translate_errors/1 (private)" do
    test "formats multiple errors correctly" do
      changeset =
        %Emailgator.Accounts.User{}
        |> Ecto.Changeset.change(%{email: nil, name: nil})
        |> Ecto.Changeset.validate_required([:email, :name])

      result = ErrorJSON.error(%{changeset: changeset})
      assert Map.has_key?(result, :errors)
    end

    test "handles errors with interpolation" do
      changeset =
        %Emailgator.Accounts.User{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:email, "must be at least %{count} characters", count: 5)

      result = ErrorJSON.error(%{changeset: changeset})
      assert Map.has_key?(result, :errors)
    end
  end
end
