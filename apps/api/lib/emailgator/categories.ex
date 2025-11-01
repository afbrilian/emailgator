defmodule Emailgator.Categories do
  @moduledoc """
  Context for managing email categories.
  """
  import Ecto.Query
  alias Emailgator.Repo
  alias Emailgator.Categories.Category

  def list_user_categories(user_id) do
    from(c in Category, where: c.user_id == ^user_id, order_by: [desc: c.inserted_at])
    |> Repo.all()
  end

  def get_category(id), do: Repo.get(Category, id)
  def get_category!(id), do: Repo.get!(Category, id)

  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end
end
