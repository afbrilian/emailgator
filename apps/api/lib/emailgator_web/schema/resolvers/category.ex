defmodule EmailgatorWeb.Schema.Resolvers.Category do
  alias Emailgator.Categories
  alias Emailgator.Accounts.User

  def list(_parent, _args, %{context: %{current_user: %User{} = user}}) do
    {:ok, Categories.list_user_categories(user.id)}
  end

  def list(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def get(_parent, %{id: id}, %{context: %{current_user: user}}) when not is_nil(user) do
    case Categories.get_category(id) do
      nil -> {:error, "Category not found"}
      category -> {:ok, category}
    end
  end

  def get(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def create(_parent, args, %{context: %{current_user: %User{} = user}}) do
    args
    |> Map.put(:user_id, user.id)
    |> Categories.create_category()
  end

  def create(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def update(_parent, %{id: id} = args, %{context: %{current_user: user}})
      when not is_nil(user) do
    case Categories.get_category(id) do
      nil -> {:error, "Category not found"}
      category -> Categories.update_category(category, args)
    end
  end

  def update(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end

  def delete(_parent, %{id: id}, %{context: %{current_user: user}}) when not is_nil(user) do
    case Categories.get_category(id) do
      nil -> {:error, "Category not found"}
      category -> Categories.delete_category(category)
    end
  end

  def delete(_parent, _args, _context) do
    {:error, "Not authenticated"}
  end
end
